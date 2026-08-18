package runtime

import (
	"encoding/json"
	"fmt"
	"strings"
	"unicode/utf8"

	"github.com/0xfe10/cel-bridge/runtime/internal/celtype"
	"github.com/0xfe10/cel-bridge/runtime/internal/environment"
	"github.com/0xfe10/cel-bridge/runtime/internal/protocol"
)

type evaluationRequest struct {
	ID                 string          `json:"id"`
	Source             string          `json:"source"`
	ProgramID          string          `json:"programId"`
	Variables          json.RawMessage `json:"variables"`
	ExpectedResultType json.RawMessage `json:"expectedResultType"`
}

func (r *Runtime) EvaluateRequests(environmentJSON, requestsJSON, optionsJSON string) (response protocol.Response) {
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
	deadline := options.Deadline()
	requests, err := r.decodeEvaluationRequests(requestsJSON)
	if err != nil {
		return protocol.Failure("invalid_request", err.Error())
	}
	results := make([]protocol.RequestResult, 0, len(requests))
	if len(requests) == 0 {
		return protocol.Success(results)
	}
	for _, request := range requests {
		if deadline.Exceeded() {
			fail := protocol.Failure("deadline_exceeded", "evaluation deadline exceeded")
			results = append(results, protocol.RequestResult{
				ID:    request.ID,
				OK:    false,
				Error: fail.Error,
			})
			continue
		}
		item := r.evaluateRequest(environmentJSON, request, options)
		results = append(results, protocol.RequestResult{
			ID:     request.ID,
			OK:     item.OK,
			Result: item.Result,
			Error:  item.Error,
		})
	}
	return protocol.Success(results)
}

func (r *Runtime) evaluateRequest(environmentJSON string, request evaluationRequest, options celtype.Options) protocol.Response {
	expected, err := parseOptionalType(request.ExpectedResultType)
	if err != nil {
		return protocol.Failure("invalid_request", err.Error())
	}
	if expected == nil {
		expected = options.Expected
	}
	hasSource := strings.TrimSpace(request.Source) != ""
	hasProgram := strings.TrimSpace(request.ProgramID) != ""
	if hasSource == hasProgram {
		return protocol.Failure("invalid_request", "request must include exactly one of source or programId")
	}
	variablesJSON := "{}"
	if len(request.Variables) > 0 && string(request.Variables) != "null" {
		variablesJSON = string(request.Variables)
	}
	if hasProgram {
		return r.evaluatePreparedProgram(request.ProgramID, variablesJSON, expected)
	}
	return r.evaluateInternal(environmentJSON, request.Source, variablesJSON, celtype.Options{Expected: expected})
}

func (r *Runtime) decodeEvaluationRequests(raw string) ([]evaluationRequest, error) {
	if !utf8.ValidString(raw) {
		return nil, fmt.Errorf("requests JSON must be valid UTF-8")
	}
	if len(raw) > r.limits.MaxBatchSourceBytes+r.limits.MaxVariablesBytes+4096 {
		return nil, fmt.Errorf("requests JSON exceeds size limit")
	}
	decoder := json.NewDecoder(strings.NewReader(raw))
	decoder.DisallowUnknownFields()
	var requests []evaluationRequest
	if err := decoder.Decode(&requests); err != nil {
		return nil, fmt.Errorf("requests JSON must be an array of objects")
	}
	if decoder.More() {
		return nil, fmt.Errorf("requests JSON contains trailing data")
	}
	if len(requests) > r.limits.MaxBatchExpressions {
		return nil, fmt.Errorf("batch exceeds %d expressions", r.limits.MaxBatchExpressions)
	}
	seen := make(map[string]struct{}, len(requests))
	for _, request := range requests {
		if strings.TrimSpace(request.ID) == "" {
			return nil, fmt.Errorf("request id is required")
		}
		if _, exists := seen[request.ID]; exists {
			return nil, fmt.Errorf("duplicate request id %q", request.ID)
		}
		seen[request.ID] = struct{}{}
	}
	return requests, nil
}

func parseOptionalType(raw json.RawMessage) (*environment.TypeSpec, error) {
	raw = json.RawMessage(strings.TrimSpace(string(raw)))
	if len(raw) == 0 || string(raw) == "null" {
		return nil, nil
	}
	spec, err := celtype.Parse(raw)
	if err != nil {
		return nil, err
	}
	return &spec, nil
}
