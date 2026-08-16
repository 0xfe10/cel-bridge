package runtime

import (
	"errors"
	"fmt"
	"strings"
	"unicode/utf8"

	"github.com/google/cel-go/cel"
	"github.com/google/cel-go/common/types"
	"github.com/google/cel-go/interpreter"

	"github.com/0xfe10/cel-bridge/internal/environment"
	"github.com/0xfe10/cel-bridge/internal/protocol"
)

type Runtime struct {
	limits Limits
}

func New(limits Limits) *Runtime {
	return &Runtime{limits: limits}
}

func (r *Runtime) Validate(environmentJSON, source string) (response protocol.Response) {
	defer func() {
		if recover() != nil {
			response = protocol.Failure("internal_error", "runtime panic recovered")
		}
	}()
	if err := r.validateSource(source); err != nil {
		return protocol.Failure(errorCode(err), err.Error())
	}
	environmentValue, err := r.decodeEnvironment(environmentJSON)
	if err != nil {
		return protocol.Failure(errorCode(err), err.Error())
	}
	celEnvironment, err := newEnvironment(environmentValue)
	if err != nil {
		return protocol.Failure("invalid_environment", err.Error())
	}
	_, issues := celEnvironment.Compile(source)
	if issues.Err() != nil {
		return protocol.Success(protocol.ValidationResult{
			Valid:  false,
			Issues: convertIssues(issues, r.limits.MaxIssues),
		})
	}
	return protocol.Success(protocol.ValidationResult{Valid: true, Issues: []protocol.Issue{}})
}

func (r *Runtime) Evaluate(environmentJSON, source, variablesJSON string) (response protocol.Response) {
	defer func() {
		if recover() != nil {
			response = protocol.Failure("internal_error", "runtime panic recovered")
		}
	}()
	if err := r.validateSource(source); err != nil {
		return protocol.Failure(errorCode(err), err.Error())
	}
	environmentValue, err := r.decodeEnvironment(environmentJSON)
	if err != nil {
		return protocol.Failure(errorCode(err), err.Error())
	}
	variables, err := protocol.DecodeVariables(variablesJSON, r.limits.MaxVariablesBytes, r.limits.MaxValueDepth)
	if err != nil {
		if len(variablesJSON) > r.limits.MaxVariablesBytes {
			return protocol.Failure("variables_too_large", err.Error())
		}
		return protocol.Failure("invalid_request", err.Error())
	}
	celEnvironment, err := newEnvironment(environmentValue)
	if err != nil {
		return protocol.Failure("invalid_environment", err.Error())
	}
	ast, issues := celEnvironment.Compile(source)
	if issues.Err() != nil {
		return protocol.Failure("compile_error", issues.String(), convertIssues(issues, r.limits.MaxIssues)...)
	}
	program, err := celEnvironment.Program(ast, cel.EvalOptions(cel.OptTrackCost), cel.CostLimit(r.limits.MaxCost))
	if err != nil {
		return protocol.Failure("compile_error", err.Error())
	}
	value, _, evalErr := program.Eval(variables)
	if evalErr != nil {
		if isCostLimitError(evalErr) {
			return protocol.Failure("cost_limit_exceeded", "CEL evaluation cost limit exceeded")
		}
		return protocol.Failure("evaluation_error", safeErrorMessage(evalErr))
	}
	if types.IsError(value) {
		celError := value.(error)
		if strings.Contains(celError.Error(), "actual cost limit exceeded") {
			return protocol.Failure("cost_limit_exceeded", "CEL evaluation cost limit exceeded")
		}
		return protocol.Failure("evaluation_error", safeErrorMessage(celError))
	}
	encoded, err := protocol.EncodeValue(value)
	if err != nil {
		return protocol.Failure("unsupported_value", err.Error())
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

func (r *Runtime) validateSource(source string) error {
	if len(source) > r.limits.MaxSourceBytes {
		return fmt.Errorf("source exceeds %d bytes", r.limits.MaxSourceBytes)
	}
	if !utf8.ValidString(source) {
		return errors.New("source must be valid UTF-8")
	}
	return nil
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
	switch {
	case strings.Contains(message, "undeclared reference"):
		return "undeclared_reference"
	case strings.Contains(message, "Syntax error"), strings.Contains(message, "syntax error"):
		return "parse_error"
	case strings.Contains(message, "type-check"), strings.Contains(message, "found no matching overload"):
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
