package runtime

import (
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"sync"
	"sync/atomic"
	"unicode/utf8"

	"github.com/google/cel-go/cel"
	"github.com/google/cel-go/common/types"
	"github.com/google/cel-go/interpreter"

	"github.com/0xfe10/cel-bridge/runtime/internal/celtype"
	"github.com/0xfe10/cel-bridge/runtime/internal/environment"
	"github.com/0xfe10/cel-bridge/runtime/internal/protocol"
)

type Runtime struct {
	limits       Limits
	profile      string
	programs     *programCache
	environments *environmentCache
	prepared     *preparedStore
	flight       *compileFlight
	compiles     atomic.Int64
	closed       atomic.Bool
	inflight     sync.WaitGroup
}

func New(limits Limits) *Runtime {
	return NewProfile(ProfileDefault, limits)
}

func NewProfile(profile string, limits Limits) *Runtime {
	if profile == "" {
		profile = ProfileDefault
	}
	return &Runtime{
		limits:       limits,
		profile:      profile,
		programs:     newProgramCache(limits.MaxCompiledPrograms),
		environments: newEnvironmentCache(limits.MaxCachedEnvironments),
		prepared:     newPreparedStore(limits.MaxPreparedPrograms),
		flight:       newCompileFlight(),
	}
}

func (r *Runtime) begin() (protocol.Response, bool) {
	if r.closed.Load() {
		return protocol.Failure("runtime_closed", "runtime has been disposed"), false
	}
	r.inflight.Add(1)
	if r.closed.Load() {
		r.inflight.Done()
		return protocol.Failure("runtime_closed", "runtime has been disposed"), false
	}
	return protocol.Response{}, true
}

func (r *Runtime) end() {
	r.inflight.Done()
}

func (r *Runtime) Closed() bool {
	return r.closed.Load()
}

func (r *Runtime) Profile() string {
	return r.profile
}

func (r *Runtime) Limits() Limits {
	return r.limits
}

func (r *Runtime) Validate(environmentJSON, source string, optionsJSON ...string) (response protocol.Response) {
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
	options, err := celtype.ParseOptions(firstOption(optionsJSON))
	if err != nil {
		return protocol.Failure("invalid_request", err.Error())
	}
	environmentValue, err := r.decodeEnvironment(environmentJSON)
	if err != nil {
		return protocol.Failure(errorCode(err), err.Error())
	}
	celEnvironment, err := newEnvironment(environmentValue)
	if err != nil {
		return protocol.Failure("invalid_environment", err.Error())
	}
	ast, issues := celEnvironment.Parse(source)
	if issues.Err() != nil {
		return protocol.Success(protocol.ValidationResult{
			Valid:  false,
			Issues: convertIssues(issues, r.limits.MaxIssues),
		})
	}
	ast, issues = celEnvironment.Check(ast)
	if issues.Err() != nil {
		return protocol.Success(protocol.ValidationResult{
			Valid:  false,
			Issues: convertIssues(issues, r.limits.MaxIssues),
		})
	}
	resultType := celtype.FromCEL(ast.OutputType())
	ref := resultType.ToRef()
	if options.Expected != nil {
		ok, _ := celtype.Compatible(resultType, *options.Expected)
		if !ok {
			return protocol.Success(protocol.ValidationResult{
				Valid:      false,
				ResultType: &ref,
				Issues: []protocol.Issue{{
					Severity: "error",
					Code:     "result_type_mismatch",
					Message:  celtype.StaticMismatchMessage(options.Expected.Format(), resultType.Format()),
				}},
			})
		}
	}
	return protocol.Success(protocol.ValidationResult{
		Valid:      true,
		ResultType: &ref,
		Issues:     []protocol.Issue{},
	})
}

func (r *Runtime) Evaluate(environmentJSON, source, variablesJSON string, optionsJSON ...string) (response protocol.Response) {
	defer func() {
		if recover() != nil {
			response = protocol.Failure("internal_error", "runtime panic recovered")
		}
	}()
	if fail, ok := r.begin(); !ok {
		return fail
	}
	defer r.end()
	options, err := celtype.ParseOptions(firstOption(optionsJSON))
	if err != nil {
		return protocol.Failure("invalid_request", err.Error())
	}
	if options.Deadline().Exceeded() {
		return protocol.Failure("deadline_exceeded", "evaluation deadline exceeded")
	}
	return r.evaluateInternal(environmentJSON, source, variablesJSON, options)
}

func (r *Runtime) evaluateInternal(environmentJSON, source, variablesJSON string, options celtype.Options) protocol.Response {
	if err := r.validateSource(source); err != nil {
		return protocol.Failure(errorCode(err), err.Error())
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
	variables, err := r.decodeVariables(variablesJSON)
	if err != nil {
		return variableError(err, len(variablesJSON), r.limits.MaxVariablesBytes)
	}
	program, fail, ok := r.getOrCompile(celEnvironment, environmentJSON, source)
	if !ok {
		return fail
	}
	return r.evalProgram(program, variables, options.Expected)
}

func (r *Runtime) EvaluateMany(environmentJSON, sourcesJSON, variablesJSON string) (response protocol.Response) {
	defer func() {
		if recover() != nil {
			response = protocol.Failure("internal_error", "runtime panic recovered")
		}
	}()
	if fail, ok := r.begin(); !ok {
		return fail
	}
	defer r.end()
	sources, err := r.decodeSources(sourcesJSON)
	if err != nil {
		return protocol.Failure("invalid_request", err.Error())
	}
	items := make([]protocol.Response, 0, len(sources))
	if len(sources) == 0 {
		return protocol.Success(&items)
	}
	celEnvironment, fail, ok := r.envFor(environmentJSON)
	if !ok {
		return fail
	}
	variables, err := r.decodeVariables(variablesJSON)
	if err != nil {
		return variableError(err, len(variablesJSON), r.limits.MaxVariablesBytes)
	}
	for _, source := range sources {
		items = append(items, r.evaluatePrepared(celEnvironment, environmentJSON, source, variables, nil))
	}
	return protocol.Success(&items)
}

func (r *Runtime) evaluatePrepared(
	celEnvironment *cel.Env,
	environmentJSON, source string,
	variables map[string]any,
	expected *environment.TypeSpec,
) protocol.Response {
	if err := r.validateSource(source); err != nil {
		return protocol.Failure(errorCode(err), err.Error())
	}
	program, fail, ok := r.getOrCompile(celEnvironment, environmentJSON, source)
	if !ok {
		return fail
	}
	return r.evalProgram(program, variables, expected)
}

func (r *Runtime) getOrCompile(celEnvironment *cel.Env, environmentJSON, source string) (cel.Program, protocol.Response, bool) {
	key := makeProgramKey(environmentJSON, source)
	if program, ok := r.programs.Get(key); ok {
		return program, protocol.Response{}, true
	}
	return r.flight.Do(key, func() (cel.Program, protocol.Response, bool) {
		if program, ok := r.programs.Get(key); ok {
			return program, protocol.Response{}, true
		}
		program, fail, ok := r.compileWithEnv(celEnvironment, source)
		if ok {
			r.programs.Put(key, program)
		}
		return program, fail, ok
	})
}

func (r *Runtime) envFor(environmentJSON string) (*cel.Env, protocol.Response, bool) {
	key := makeEnvironmentKey(environmentJSON)
	if env, ok := r.environments.Get(key); ok {
		return env, protocol.Response{}, true
	}
	environmentValue, err := r.decodeEnvironment(environmentJSON)
	if err != nil {
		return nil, protocol.Failure(errorCode(err), err.Error()), false
	}
	celEnvironment, err := newEnvironment(environmentValue)
	if err != nil {
		return nil, protocol.Failure("invalid_environment", err.Error()), false
	}
	r.environments.Put(key, celEnvironment)
	return celEnvironment, protocol.Response{}, true
}

func (r *Runtime) compileWithEnv(celEnvironment *cel.Env, source string) (cel.Program, protocol.Response, bool) {
	ast, issues := celEnvironment.Parse(source)
	if issues.Err() != nil {
		return nil, protocol.Failure("parse_error", issues.String(), convertIssues(issues, r.limits.MaxIssues)...), false
	}
	ast, issues = celEnvironment.Check(ast)
	if issues.Err() != nil {
		return nil, protocol.Failure("compile_error", issues.String(), convertIssues(issues, r.limits.MaxIssues)...), false
	}
	program, err := celEnvironment.Program(ast, cel.EvalOptions(cel.OptTrackCost), cel.CostLimit(r.limits.MaxCost))
	if err != nil {
		return nil, protocol.Failure("compile_error", err.Error()), false
	}
	r.compiles.Add(1)
	return program, protocol.Response{}, true
}

func (r *Runtime) evalProgram(
	program cel.Program,
	variables map[string]any,
	expected *environment.TypeSpec,
) protocol.Response {
	activation := &trackingActivation{vars: variables}
	value, _, evalErr := program.Eval(activation)
	if evalErr != nil {
		if isCostLimitError(evalErr) {
			return protocol.Failure("cost_limit_exceeded", "CEL evaluation cost limit exceeded")
		}
		if len(activation.missing) > 0 {
			return protocol.Failure("missing_variable", "missing variable "+activation.missing[0])
		}
		return protocol.Failure("evaluation_error", safeErrorMessage(evalErr))
	}
	if types.IsError(value) {
		celError := value.(error)
		if isCostLimitError(celError) || strings.Contains(celError.Error(), "actual cost limit exceeded") {
			return protocol.Failure("cost_limit_exceeded", "CEL evaluation cost limit exceeded")
		}
		if len(activation.missing) > 0 {
			return protocol.Failure("missing_variable", "missing variable "+activation.missing[0])
		}
		return protocol.Failure("evaluation_error", safeErrorMessage(celError))
	}
	encoded, err := protocol.EncodeValue(value)
	if err != nil {
		return protocol.Failure("unsupported_value", err.Error())
	}
	if expected != nil && !celtype.MatchesValue(*expected, encoded) {
		return protocol.Failure(
			"result_type_mismatch",
			celtype.MismatchMessage(expected.Format(), encoded.Kind),
		)
	}
	return protocol.Success(encoded)
}

func (r *Runtime) JSON(response protocol.Response) string {
	encoded := protocol.JSON(response)
	if len(encoded) <= r.limits.MaxOutputBytes {
		return encoded
	}
	return protocol.JSON(protocol.Failure("output_too_large", "response exceeds output limit"))
}

func (r *Runtime) decodeEnvironment(raw string) (environment.Environment, error) {
	if len(raw) > r.limits.MaxEnvironmentBytes {
		return environment.Environment{}, fmt.Errorf("environment JSON exceeds %d bytes", r.limits.MaxEnvironmentBytes)
	}
	if !utf8.ValidString(raw) {
		return environment.Environment{}, errors.New("environment JSON must be valid UTF-8")
	}
	value, err := environment.Decode(raw, r.limits.MaxTypeDepth)
	if err != nil {
		return environment.Environment{}, err
	}
	return value, nil
}

func (r *Runtime) decodeVariables(raw string) (map[string]any, error) {
	return protocol.DecodeVariables(raw, r.limits.MaxVariablesBytes, r.limits.MaxValueDepth)
}

func (r *Runtime) decodeSources(raw string) ([]string, error) {
	if !utf8.ValidString(raw) {
		return nil, errors.New("sources JSON must be valid UTF-8")
	}
	if len(raw) > r.limits.MaxBatchSourceBytes+4096 {
		return nil, fmt.Errorf("sources JSON exceeds %d bytes", r.limits.MaxBatchSourceBytes+4096)
	}
	decoder := json.NewDecoder(strings.NewReader(raw))
	var values []json.RawMessage
	if err := decoder.Decode(&values); err != nil {
		return nil, fmt.Errorf("sources JSON must be an array of strings")
	}
	if decoder.More() {
		return nil, errors.New("sources JSON contains trailing data")
	}
	if len(values) > r.limits.MaxBatchExpressions {
		return nil, fmt.Errorf("batch exceeds %d expressions", r.limits.MaxBatchExpressions)
	}
	sources := make([]string, 0, len(values))
	total := 0
	for _, value := range values {
		var source string
		if err := json.Unmarshal(value, &source); err != nil {
			return nil, errors.New("sources JSON must be an array of strings")
		}
		total += len(source)
		if total > r.limits.MaxBatchSourceBytes {
			return nil, fmt.Errorf("batch source exceeds %d bytes", r.limits.MaxBatchSourceBytes)
		}
		sources = append(sources, source)
	}
	return sources, nil
}

func firstOption(options []string) string {
	if len(options) == 0 {
		return ""
	}
	return options[0]
}

func (r *Runtime) validateSource(source string) error {
	if len(source) > r.limits.MaxSourceBytes {
		return fmt.Errorf("source exceeds %d bytes", r.limits.MaxSourceBytes)
	}
	if !utf8.ValidString(source) {
		return errors.New("source must be valid UTF-8")
	}
	return nil
}

func (r *Runtime) compiledCount() int64 {
	return r.compiles.Load()
}

func (r *Runtime) programCacheLen() int {
	return r.programs.Len()
}

func newEnvironment(value environment.Environment) (*cel.Env, error) {
	options := make([]cel.EnvOption, 0, len(value.Variables))
	for name, spec := range value.Variables {
		celType, err := spec.CELType()
		if err != nil {
			return nil, fmt.Errorf("variable %q: %w", name, err)
		}
		options = append(options, cel.Variable(name, celType))
	}
	return cel.NewEnv(options...)
}

func convertIssues(issues *cel.Issues, maxIssues int) []protocol.Issue {
	celIssues := issues.Errors()
	if len(celIssues) > maxIssues {
		celIssues = celIssues[:maxIssues]
	}
	result := make([]protocol.Issue, 0, len(celIssues))
	for _, issue := range celIssues {
		result = append(result, protocol.Issue{
			Severity: "error",
			Code:     classifyIssue(issue.Message),
			Message:  issue.Message,
			Line:     issue.Location.Line(),
			Column:   issue.Location.Column() + 1,
		})
	}
	return result
}

func classifyIssue(message string) string {
	lower := strings.ToLower(message)
	switch {
	case strings.Contains(lower, "undeclared reference"):
		return "undeclared_reference"
	case strings.Contains(lower, "syntax error"):
		return "parse_error"
	case strings.Contains(lower, "found no matching overload"),
		strings.Contains(lower, "no matching overload"),
		strings.Contains(lower, "type-check error"):
		return "type_error"
	default:
		return "compile_error"
	}
}

func errorCode(err error) string {
	if strings.Contains(err.Error(), "source exceeds") {
		return "source_too_large"
	}
	if strings.Contains(err.Error(), "environment JSON") || strings.Contains(err.Error(), "schemaVersion") || strings.Contains(err.Error(), "variable") || strings.Contains(err.Error(), "type") {
		return "invalid_environment"
	}
	return "invalid_request"
}

func variableError(err error, size, limit int) protocol.Response {
	if size > limit {
		return protocol.Failure("variables_too_large", err.Error())
	}
	return protocol.Failure("invalid_request", err.Error())
}

func isCostLimitError(err error) bool {
	var cancelled interpreter.EvalCancelledError
	return errors.As(err, &cancelled) && cancelled.Cause == interpreter.CostLimitExceeded
}

func safeErrorMessage(err error) string {
	message := strings.TrimSpace(err.Error())
	if len(message) > 2048 {
		return message[:2048]
	}
	return message
}
