package celbridge

import (
	"sync"

	"github.com/0xfe10/cel-bridge/runtime/internal/protocol"
	"github.com/0xfe10/cel-bridge/runtime/internal/runtime"
)

func failCreate(message string) protocol.Response {
	return protocol.Failure("invalid_request", message)
}

var (
	defaultMu      sync.Mutex
	defaultRuntime = runtime.New(runtime.DefaultLimits)
)

func currentRuntime() *runtime.Runtime {
	defaultMu.Lock()
	defer defaultMu.Unlock()
	return defaultRuntime
}

func Validate(environmentJSON string, source string, optionsJSON ...string) string {
	rt := currentRuntime()
	return rt.JSON(rt.Validate(environmentJSON, source, optionsJSON...))
}

func Evaluate(environmentJSON string, source string, variablesJSON string, optionsJSON ...string) string {
	rt := currentRuntime()
	return rt.JSON(rt.Evaluate(environmentJSON, source, variablesJSON, optionsJSON...))
}

func EvaluateMany(environmentJSON string, sourcesJSON string, variablesJSON string) string {
	rt := currentRuntime()
	return rt.JSON(rt.EvaluateMany(environmentJSON, sourcesJSON, variablesJSON))
}

func EvaluateRequests(environmentJSON, requestsJSON string, optionsJSON ...string) string {
	rt := currentRuntime()
	return rt.JSON(rt.EvaluateRequests(environmentJSON, requestsJSON, firstOption(optionsJSON)))
}

func Prepare(environmentJSON, source string, optionsJSON ...string) string {
	rt := currentRuntime()
	return rt.JSON(rt.Prepare(environmentJSON, source, firstOption(optionsJSON)))
}

func EvaluateProgram(programID, variablesJSON string, optionsJSON ...string) string {
	rt := currentRuntime()
	return rt.JSON(rt.EvaluateProgram(programID, variablesJSON, firstOption(optionsJSON)))
}

func ReleaseProgram(programID string) string {
	rt := currentRuntime()
	return rt.JSON(rt.ReleaseProgram(programID))
}

func Close() string {
	defaultMu.Lock()
	rt := defaultRuntime
	defaultMu.Unlock()
	return rt.JSON(rt.Close())
}

func Create(optionsJSON string) string {
	profile, limits, err := runtime.ParseCreateOptions(optionsJSON)
	if err != nil {
		return runtime.New(runtime.DefaultLimits).JSON(failCreate(err.Error()))
	}
	created := runtime.NewProfile(profile, limits)
	defaultMu.Lock()
	previous := defaultRuntime
	defaultRuntime = created
	defaultMu.Unlock()
	if previous != nil && !previous.Closed() {
		previous.Close()
	}
	return RuntimeInfo()
}

func firstOption(options []string) string {
	if len(options) == 0 {
		return ""
	}
	return options[0]
}
