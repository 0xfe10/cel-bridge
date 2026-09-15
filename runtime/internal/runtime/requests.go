package runtime

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"strings"
	"unicode/utf8"

	"github.com/0xfe10/cel-bridge/runtime/internal/celtype"
	"github.com/0xfe10/cel-bridge/runtime/internal/environment"
	"github.com/0xfe10/cel-bridge/runtime/internal/protocol"
)

type evaluationRequestWire struct {
	ID                 string          `json:"id"`
	Source             string          `json:"source"`
	ProgramID          string          `json:"programId"`
	Variables          json.RawMessage `json:"variables"`
	ExpectedResultType json.RawMessage `json:"expectedResultType"`
}

type evaluationEnvelopeWire struct {
	SharedVariables json.RawMessage `json:"sharedVariables"`
	Requests        json.RawMessage `json:"requests"`
}

type evaluationRequest struct {
	ID                 string
	Source             string
	ProgramID          string
	Variables          json.RawMessage
	variableObject     map[string]json.RawMessage
	ExpectedResultType json.RawMessage
}

type evaluationEnvelope struct {
	SharedVariables map[string]any
	sharedObject    map[string]json.RawMessage
	Requests        []evaluationRequest
}

type requestDecodeError struct {
	code    string
	message string
	details map[string]any
}

func (e *requestDecodeError) Error() string { return e.message }

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
	envelope, err := r.decodeEvaluationRequests(requestsJSON)
	if err != nil {
		if decodeError, ok := err.(*requestDecodeError); ok {
			return protocol.FailureWithDetails(decodeError.code, decodeError.message, decodeError.details)
		}
		return protocol.Failure("invalid_request", err.Error())
	}
	results := make([]protocol.RequestResult, 0, len(envelope.Requests))
	if len(envelope.Requests) == 0 {
		return protocol.Success(results)
	}
	for _, request := range envelope.Requests {
		if deadline.Exceeded() {
			fail := protocol.Failure("deadline_exceeded", "evaluation deadline exceeded")
			results = append(results, protocol.RequestResult{ID: request.ID, OK: false, Error: fail.Error})
			continue
		}
		var item protocol.Response
		actualBytes := mergedVariableObjectSize(envelope.sharedObject, request.variableObject)
		if actualBytes > r.limits.MaxVariablesBytes {
			item = protocol.FailureWithDetails(
				"variables_too_large",
				fmt.Sprintf("merged request variables exceed %d bytes", r.limits.MaxVariablesBytes),
				map[string]any{"actualBytes": actualBytes, "maxBytes": r.limits.MaxVariablesBytes, "retryable": false},
			)
		} else {
			requestVariables, decodeErr := r.decodeVariables(string(request.Variables))
			if decodeErr != nil {
				item = variableError(decodeErr, len(request.Variables), r.limits.MaxVariablesBytes)
			} else {
				variables := mergeDecodedVariables(envelope.SharedVariables, requestVariables)
				item = r.evaluateRequest(environmentJSON, request, variables, options)
			}
		}
		results = append(results, protocol.RequestResult{ID: request.ID, OK: item.OK, Result: item.Result, Error: item.Error})
	}
	return protocol.Success(results)
}

func (r *Runtime) evaluateRequest(environmentJSON string, request evaluationRequest, variables map[string]any, options celtype.Options) protocol.Response {
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
	if hasProgram {
		return r.evaluatePreparedProgramVariables(request.ProgramID, variables, expected)
	}
	return r.evaluateInternalVariables(environmentJSON, request.Source, variables, expected)
}

func (r *Runtime) decodeEvaluationRequests(raw string) (evaluationEnvelope, error) {
	if !utf8.ValidString(raw) {
		return evaluationEnvelope{}, fmt.Errorf("requests JSON must be valid UTF-8")
	}
	if len(raw) > r.limits.MaxBatchRequestBytes {
		return evaluationEnvelope{}, &requestDecodeError{
			code: "batch_payload_too_large", message: fmt.Sprintf("request batch exceeds %d bytes", r.limits.MaxBatchRequestBytes),
			details: map[string]any{"actualBytes": len(raw), "maxBytes": r.limits.MaxBatchRequestBytes, "retryable": true},
		}
	}
	decoder := json.NewDecoder(strings.NewReader(raw))
	decoder.DisallowUnknownFields()
	var wire evaluationEnvelopeWire
	if err := decoder.Decode(&wire); err != nil {
		return evaluationEnvelope{}, fmt.Errorf("requests JSON must be an envelope object")
	}
	if err := requireEOF(decoder); err != nil {
		return evaluationEnvelope{}, fmt.Errorf("requests JSON contains trailing data")
	}
	sharedObject, err := decodeRequiredVariableObject(wire.SharedVariables, "sharedVariables")
	if err != nil {
		return evaluationEnvelope{}, err
	}
	if len(wire.SharedVariables) > r.limits.MaxVariablesBytes {
		return evaluationEnvelope{}, &requestDecodeError{
			code: "variables_too_large", message: fmt.Sprintf("sharedVariables exceed %d bytes", r.limits.MaxVariablesBytes),
			details: map[string]any{"actualBytes": len(wire.SharedVariables), "maxBytes": r.limits.MaxVariablesBytes, "retryable": false},
		}
	}
	sharedVariables, err := r.decodeVariables(string(wire.SharedVariables))
	if err != nil {
		return evaluationEnvelope{}, err
	}
	requestWires, err := decodeRequiredRequestList(wire.Requests)
	if err != nil {
		return evaluationEnvelope{}, err
	}
	if len(requestWires) > r.limits.MaxBatchExpressions {
		return evaluationEnvelope{}, fmt.Errorf("batch exceeds %d expressions", r.limits.MaxBatchExpressions)
	}
	requests := make([]evaluationRequest, 0, len(requestWires))
	seen := make(map[string]struct{}, len(requestWires))
	totalSourceBytes := 0
	for _, wireRequest := range requestWires {
		if strings.TrimSpace(wireRequest.ID) == "" {
			return evaluationEnvelope{}, fmt.Errorf("request id is required")
		}
		if _, exists := seen[wireRequest.ID]; exists {
			return evaluationEnvelope{}, fmt.Errorf("duplicate request id %q", wireRequest.ID)
		}
		seen[wireRequest.ID] = struct{}{}
		totalSourceBytes += len(wireRequest.Source)
		if totalSourceBytes > r.limits.MaxBatchSourceBytes {
			return evaluationEnvelope{}, &requestDecodeError{
				code: "batch_payload_too_large", message: fmt.Sprintf("batch source exceeds %d bytes", r.limits.MaxBatchSourceBytes),
				details: map[string]any{"actualBytes": totalSourceBytes, "maxBytes": r.limits.MaxBatchSourceBytes, "retryable": true},
			}
		}
		variableObject, err := decodeRequiredVariableObject(wireRequest.Variables, "request variables")
		if err != nil {
			return evaluationEnvelope{}, err
		}
		requests = append(requests, evaluationRequest{
			ID: wireRequest.ID, Source: wireRequest.Source, ProgramID: wireRequest.ProgramID,
			Variables: wireRequest.Variables, variableObject: variableObject,
			ExpectedResultType: wireRequest.ExpectedResultType,
		})
	}
	return evaluationEnvelope{SharedVariables: sharedVariables, sharedObject: sharedObject, Requests: requests}, nil
}

func decodeRequiredRequestList(raw json.RawMessage) ([]evaluationRequestWire, error) {
	trimmed := bytes.TrimSpace(raw)
	if len(trimmed) == 0 || bytes.Equal(trimmed, []byte("null")) || trimmed[0] != '[' {
		return nil, fmt.Errorf("requests is required and must be an array")
	}
	decoder := json.NewDecoder(bytes.NewReader(trimmed))
	decoder.DisallowUnknownFields()
	var requests []evaluationRequestWire
	if err := decoder.Decode(&requests); err != nil {
		return nil, fmt.Errorf("requests must be an array: %w", err)
	}
	if err := requireEOF(decoder); err != nil {
		return nil, fmt.Errorf("requests contains trailing data")
	}
	return requests, nil
}

func decodeRequiredVariableObject(raw json.RawMessage, name string) (map[string]json.RawMessage, error) {
	trimmed := bytes.TrimSpace(raw)
	if len(trimmed) == 0 || bytes.Equal(trimmed, []byte("null")) {
		return nil, fmt.Errorf("%s is required and must be an object", name)
	}
	decoder := json.NewDecoder(bytes.NewReader(trimmed))
	token, err := decoder.Token()
	if err != nil || token != json.Delim('{') {
		return nil, fmt.Errorf("%s must be an object", name)
	}
	value := make(map[string]json.RawMessage)
	for decoder.More() {
		keyToken, err := decoder.Token()
		if err != nil {
			return nil, fmt.Errorf("%s must be an object", name)
		}
		key, ok := keyToken.(string)
		if !ok {
			return nil, fmt.Errorf("%s must be an object", name)
		}
		if _, exists := value[key]; exists {
			return nil, fmt.Errorf("%s contains duplicate key %q", name, key)
		}
		var item json.RawMessage
		if err := decoder.Decode(&item); err != nil {
			return nil, fmt.Errorf("invalid %s: %w", name, err)
		}
		var compact bytes.Buffer
		if err := json.Compact(&compact, item); err != nil {
			return nil, fmt.Errorf("invalid %s: %w", name, err)
		}
		value[key] = compact.Bytes()
	}
	if token, err := decoder.Token(); err != nil || token != json.Delim('}') {
		return nil, fmt.Errorf("%s must be an object", name)
	}
	if err := requireEOF(decoder); err != nil {
		return nil, fmt.Errorf("%s contains trailing data", name)
	}
	return value, nil
}

func mergedVariableObjectSize(shared, request map[string]json.RawMessage) int {
	size := 2
	count := 0
	add := func(key string, value json.RawMessage) {
		if count > 0 {
			size++
		}
		encodedKey, _ := json.Marshal(key)
		size += len(encodedKey) + 1 + len(value)
		count++
	}
	for key, value := range shared {
		if _, overridden := request[key]; !overridden {
			add(key, value)
		}
	}
	for key, value := range request {
		add(key, value)
	}
	return size
}

func mergeDecodedVariables(shared, request map[string]any) map[string]any {
	merged := make(map[string]any, len(shared)+len(request))
	for key, value := range shared {
		merged[key] = value
	}
	for key, value := range request {
		merged[key] = value
	}
	return merged
}

func requireEOF(decoder *json.Decoder) error {
	var trailing any
	if err := decoder.Decode(&trailing); err != io.EOF {
		if err == nil {
			return fmt.Errorf("trailing data")
		}
		return err
	}
	return nil
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
