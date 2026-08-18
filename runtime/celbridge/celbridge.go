package celbridge

import (
	"github.com/0xfe10/cel-bridge/runtime/internal/runtime"
)

var defaultRuntime = runtime.New(runtime.DefaultLimits)

func Validate(environmentJSON string, source string) string {
	return defaultRuntime.JSON(defaultRuntime.Validate(environmentJSON, source))
}

func Evaluate(environmentJSON string, source string, variablesJSON string) string {
	return defaultRuntime.JSON(defaultRuntime.Evaluate(environmentJSON, source, variablesJSON))
}

func EvaluateMany(environmentJSON string, sourcesJSON string, variablesJSON string) string {
	return defaultRuntime.JSON(defaultRuntime.EvaluateMany(environmentJSON, sourcesJSON, variablesJSON))
}
