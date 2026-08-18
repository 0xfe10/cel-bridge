package celbridge

import runtimecelbridge "github.com/0xfe10/cel-bridge/runtime/celbridge"

// Validate preserves the v0.1 Go import path while new code can use
// runtime/celbridge directly.
func Validate(environmentJSON string, source string, optionsJSON ...string) string {
	return runtimecelbridge.Validate(environmentJSON, source, optionsJSON...)
}

// Evaluate preserves the v0.1 Go import path while new code can use
// runtime/celbridge directly.
func Evaluate(environmentJSON string, source string, variablesJSON string, optionsJSON ...string) string {
	return runtimecelbridge.Evaluate(environmentJSON, source, variablesJSON, optionsJSON...)
}

// EvaluateMany preserves the v0.1 Go import path while new code can use
// runtime/celbridge directly.
func EvaluateMany(environmentJSON string, sourcesJSON string, variablesJSON string) string {
	return runtimecelbridge.EvaluateMany(environmentJSON, sourcesJSON, variablesJSON)
}

// Version preserves the v0.1 Go import path while new code can use
// runtime/celbridge directly.
func Version() string {
	return runtimecelbridge.Version()
}

// RuntimeInfo preserves the v0.1 Go import path while new code can use
// runtime/celbridge directly.
func RuntimeInfo() string {
	return runtimecelbridge.RuntimeInfo()
}

// EvaluateRequests preserves the v0.1 Go import path while new code can use
// runtime/celbridge directly.
func EvaluateRequests(environmentJSON, requestsJSON string, optionsJSON ...string) string {
	return runtimecelbridge.EvaluateRequests(environmentJSON, requestsJSON, optionsJSON...)
}

// Prepare preserves the v0.1 Go import path while new code can use
// runtime/celbridge directly.
func Prepare(environmentJSON, source string, optionsJSON ...string) string {
	return runtimecelbridge.Prepare(environmentJSON, source, optionsJSON...)
}

// EvaluateProgram preserves the v0.1 Go import path while new code can use
// runtime/celbridge directly.
func EvaluateProgram(programID, variablesJSON string, optionsJSON ...string) string {
	return runtimecelbridge.EvaluateProgram(programID, variablesJSON, optionsJSON...)
}

// ReleaseProgram preserves the v0.1 Go import path while new code can use
// runtime/celbridge directly.
func ReleaseProgram(programID string) string {
	return runtimecelbridge.ReleaseProgram(programID)
}

// Close preserves the v0.1 Go import path while new code can use
// runtime/celbridge directly.
func Close() string {
	return runtimecelbridge.Close()
}

// Create preserves the v0.1 Go import path while new code can use
// runtime/celbridge directly.
func Create(optionsJSON string) string {
	return runtimecelbridge.Create(optionsJSON)
}
