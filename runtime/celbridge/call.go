package celbridge

import (
	"encoding/json"
	"fmt"
	"strings"

	"github.com/0xfe10/cel-bridge/runtime/internal/protocol"
)

type callRequest struct {
	Op          string          `json:"op"`
	Environment json.RawMessage `json:"environment"`
	Source      string          `json:"source"`
	Sources     json.RawMessage `json:"sources"`
	Variables   json.RawMessage `json:"variables"`
	Options     json.RawMessage `json:"options"`
	Requests    json.RawMessage `json:"requests"`
	ProgramID   string          `json:"programId"`
}

func Call(requestJSON string) string {
	trimmed := strings.TrimSpace(requestJSON)
	if trimmed == "" {
		return protocol.JSON(protocol.Failure("invalid_request", "call request is required"))
	}
	decoder := json.NewDecoder(strings.NewReader(trimmed))
	decoder.DisallowUnknownFields()
	var request callRequest
	if err := decoder.Decode(&request); err != nil {
		return protocol.JSON(protocol.Failure("invalid_request", fmt.Sprintf("invalid call request: %v", err)))
	}
	if decoder.More() {
		return protocol.JSON(protocol.Failure("invalid_request", "call request contains trailing data"))
	}
	environment := rawOrObject(request.Environment)
	variables := rawOrObject(request.Variables)
	options := rawOrObject(request.Options)
	switch request.Op {
	case "validate":
		return Validate(environment, request.Source, options)
	case "evaluate":
		return Evaluate(environment, request.Source, variables, options)
	case "evaluateMany":
		return EvaluateMany(environment, rawOrArray(request.Sources), variables)
	case "evaluateRequests":
		return EvaluateRequests(environment, rawOrArray(request.Requests), options)
	case "prepare":
		return Prepare(environment, request.Source, options)
	case "evaluateProgram":
		return EvaluateProgram(request.ProgramID, variables, options)
	case "releaseProgram":
		return ReleaseProgram(request.ProgramID)
	case "close":
		return Close()
	case "create":
		return Create(options)
	case "runtimeInfo":
		return RuntimeInfo()
	default:
		return protocol.JSON(protocol.Failure("invalid_request", "unknown call op "+request.Op))
	}
}

func rawOrObject(raw json.RawMessage) string {
	if len(strings.TrimSpace(string(raw))) == 0 {
		return "{}"
	}
	return string(raw)
}

func rawOrArray(raw json.RawMessage) string {
	if len(strings.TrimSpace(string(raw))) == 0 {
		return "[]"
	}
	return string(raw)
}
