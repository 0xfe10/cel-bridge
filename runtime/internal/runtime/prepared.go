package runtime

import (
	"fmt"
	"strings"
	"sync"
	"sync/atomic"

	"github.com/google/cel-go/cel"

	"github.com/0xfe10/cel-bridge/runtime/internal/celtype"
	"github.com/0xfe10/cel-bridge/runtime/internal/environment"
	"github.com/0xfe10/cel-bridge/runtime/internal/protocol"
)

type preparedProgram struct {
	id              string
	environmentJSON string
	source          string
	expected        *environment.TypeSpec
	program         cel.Program
	celEnvironment  *cel.Env
}

type preparedStore struct {
	mu       sync.Mutex
	capacity int
	next     atomic.Uint64
	items    map[string]*preparedProgram
}

func newPreparedStore(capacity int) *preparedStore {
	if capacity < 0 {
		capacity = 0
	}
	return &preparedStore{
		capacity: capacity,
		items:    make(map[string]*preparedProgram),
	}
}

func (s *preparedStore) put(program *preparedProgram) (string, protocol.Response, bool) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.capacity == 0 || len(s.items) >= s.capacity {
		return "", protocol.Failure("program_limit_exceeded", "prepared program capacity exceeded"), false
	}
	id := fmt.Sprintf("prg_%d", s.next.Add(1))
	program.id = id
	s.items[id] = program
	return id, protocol.Response{}, true
}

func (s *preparedStore) get(id string) (*preparedProgram, bool) {
	s.mu.Lock()
	defer s.mu.Unlock()
	program, ok := s.items[id]
	return program, ok
}

func (s *preparedStore) release(id string) bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	if _, ok := s.items[id]; !ok {
		return false
	}
	delete(s.items, id)
	return true
}

func (s *preparedStore) clear() {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.items = make(map[string]*preparedProgram)
}

func (s *preparedStore) len() int {
	s.mu.Lock()
	defer s.mu.Unlock()
	return len(s.items)
}

func (r *Runtime) Prepare(environmentJSON, source, optionsJSON string) (response protocol.Response) {
	defer func() {
		if recover() != nil {
			response = protocol.Failure("internal_error", "runtime panic recovered")
		}
	}()
	if fail, ok := r.begin(); !ok {
		return fail
	}
	defer r.end()
	if err := r.validateSource(source); err != nil {
		return protocol.Failure(errorCode(err), err.Error())
	}
	options, err := celtype.ParseOptions(optionsJSON)
	if err != nil {
		return protocol.Failure("invalid_request", err.Error())
	}
	celEnvironment, fail, ok := r.envFor(environmentJSON)
	if !ok {
		return fail
	}
	if options.Expected != nil {
		ast, issues := celEnvironment.Parse(source)
		if issues.Err() != nil {
			return protocol.Failure("parse_error", issues.String(), convertIssues(issues, r.limits.MaxIssues)...)
		}
		ast, issues = celEnvironment.Check(ast)
		if issues.Err() != nil {
			return protocol.Failure("compile_error", issues.String(), convertIssues(issues, r.limits.MaxIssues)...)
		}
		resultType := celtype.FromCEL(ast.OutputType())
		compatible, _ := celtype.Compatible(resultType, *options.Expected)
		if !compatible {
			return protocol.Failure(
				"result_type_mismatch",
				celtype.StaticMismatchMessage(options.Expected.Format(), resultType.Format()),
			)
		}
	}
	program, fail, ok := r.getOrCompile(celEnvironment, environmentJSON, source)
	if !ok {
		return fail
	}
	id, fail, ok := r.prepared.put(&preparedProgram{
		environmentJSON: environmentJSON,
		source:          source,
		expected:        options.Expected,
		program:         program,
		celEnvironment:  celEnvironment,
	})
	if !ok {
		return fail
	}
	return protocol.Success(protocol.PrepareResult{ProgramID: id})
}

func (r *Runtime) EvaluateProgram(programID, variablesJSON, optionsJSON string) (response protocol.Response) {
	defer func() {
		if recover() != nil {
			response = protocol.Failure("internal_error", "runtime panic recovered")
		}
	}()
	if fail, ok := r.begin(); !ok {
		return fail
	}
	defer r.end()
	options, err := celtype.ParseOptions(optionsJSON)
	if err != nil {
		return protocol.Failure("invalid_request", err.Error())
	}
	if options.Deadline().Exceeded() {
		return protocol.Failure("deadline_exceeded", "evaluation deadline exceeded")
	}
	return r.evaluatePreparedProgram(programID, variablesJSON, options.Expected)
}

func (r *Runtime) ReleaseProgram(programID string) (response protocol.Response) {
	defer func() {
		if recover() != nil {
			response = protocol.Failure("internal_error", "runtime panic recovered")
		}
	}()
	if fail, ok := r.begin(); !ok {
		return fail
	}
	defer r.end()
	if strings.TrimSpace(programID) == "" {
		return protocol.Failure("invalid_request", "programId is required")
	}
	if !r.prepared.release(programID) {
		return protocol.Failure("program_not_found", "prepared program was not found")
	}
	return protocol.Success(protocol.ReleaseResult{Released: true})
}

func (r *Runtime) evaluatePreparedProgram(programID, variablesJSON string, extraExpected *environment.TypeSpec) protocol.Response {
	prepared, ok := r.prepared.get(programID)
	if !ok {
		return protocol.Failure("program_not_found", "prepared program was not found")
	}
	variables, err := r.decodeVariables(variablesJSON)
	if err != nil {
		return variableError(err, len(variablesJSON), r.limits.MaxVariablesBytes)
	}
	expected := prepared.expected
	if extraExpected != nil {
		expected = extraExpected
	}
	return r.evalProgram(prepared.program, variables, expected)
}

func (r *Runtime) Close() (response protocol.Response) {
	defer func() {
		if recover() != nil {
			response = protocol.Failure("internal_error", "runtime panic recovered")
		}
	}()
	if r.closed.Swap(true) {
		return protocol.Success(protocol.CloseResult{Closed: true})
	}
	r.inflight.Wait()
	r.prepared.clear()
	return protocol.Success(protocol.CloseResult{Closed: true})
}
