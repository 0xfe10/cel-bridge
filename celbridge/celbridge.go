package celbridge

import runtimecelbridge "github.com/0xfe10/cel-bridge/runtime/celbridge"

// Validate preserves the v0.1 Go import path while new code can use
// runtime/celbridge directly.
func Validate(environmentJSON string, source string) string {
	return runtimecelbridge.Validate(environmentJSON, source)
}

// Evaluate preserves the v0.1 Go import path while new code can use
// runtime/celbridge directly.
func Evaluate(environmentJSON string, source string, variablesJSON string) string {
	return runtimecelbridge.Evaluate(environmentJSON, source, variablesJSON)
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
