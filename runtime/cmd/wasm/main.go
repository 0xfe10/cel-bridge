//go:build js && wasm

package main

import (
	"syscall/js"

	"github.com/0xfe10/cel-bridge/runtime/celbridge"
	"github.com/0xfe10/cel-bridge/runtime/internal/protocol"
)

var functions []js.Func

func stringArgument(args []js.Value, index int) (string, bool) {
	if index >= len(args) || args[index].Type() != js.TypeString {
		return "", false
	}
	return args[index].String(), true
}

func optionalStringArgument(args []js.Value, index int) (string, bool) {
	if index >= len(args) {
		return "", true
	}
	if args[index].Type() != js.TypeString {
		return "", false
	}
	return args[index].String(), true
}

func invalidRequestValue() js.Value {
	return js.ValueOf(protocol.JSON(protocol.Failure("invalid_request", "Wasm arguments must be strings")))
}

func main() {
	functions = append(functions,
		js.FuncOf(func(js.Value, []js.Value) any { return celbridge.Version() }),
		js.FuncOf(func(js.Value, []js.Value) any { return celbridge.RuntimeInfo() }),
		js.FuncOf(func(_ js.Value, args []js.Value) any {
			environment, environmentOK := stringArgument(args, 0)
			source, sourceOK := stringArgument(args, 1)
			options, optionsOK := optionalStringArgument(args, 2)
			if !environmentOK || !sourceOK || !optionsOK {
				return invalidRequestValue()
			}
			return celbridge.Validate(environment, source, options)
		}),
		js.FuncOf(func(_ js.Value, args []js.Value) any {
			environment, environmentOK := stringArgument(args, 0)
			source, sourceOK := stringArgument(args, 1)
			variables, variablesOK := stringArgument(args, 2)
			options, optionsOK := optionalStringArgument(args, 3)
			if !environmentOK || !sourceOK || !variablesOK || !optionsOK {
				return invalidRequestValue()
			}
			return celbridge.Evaluate(environment, source, variables, options)
		}),
		js.FuncOf(func(_ js.Value, args []js.Value) any {
			environment, environmentOK := stringArgument(args, 0)
			sources, sourcesOK := stringArgument(args, 1)
			variables, variablesOK := stringArgument(args, 2)
			if !environmentOK || !sourcesOK || !variablesOK {
				return invalidRequestValue()
			}
			return celbridge.EvaluateMany(environment, sources, variables)
		}),
		js.FuncOf(func(_ js.Value, args []js.Value) any {
			environment, environmentOK := stringArgument(args, 0)
			requests, requestsOK := stringArgument(args, 1)
			options, optionsOK := optionalStringArgument(args, 2)
			if !environmentOK || !requestsOK || !optionsOK {
				return invalidRequestValue()
			}
			return celbridge.EvaluateRequests(environment, requests, options)
		}),
		js.FuncOf(func(_ js.Value, args []js.Value) any {
			environment, environmentOK := stringArgument(args, 0)
			source, sourceOK := stringArgument(args, 1)
			options, optionsOK := optionalStringArgument(args, 2)
			if !environmentOK || !sourceOK || !optionsOK {
				return invalidRequestValue()
			}
			return celbridge.Prepare(environment, source, options)
		}),
		js.FuncOf(func(_ js.Value, args []js.Value) any {
			programID, idOK := stringArgument(args, 0)
			variables, variablesOK := stringArgument(args, 1)
			options, optionsOK := optionalStringArgument(args, 2)
			if !idOK || !variablesOK || !optionsOK {
				return invalidRequestValue()
			}
			return celbridge.EvaluateProgram(programID, variables, options)
		}),
		js.FuncOf(func(_ js.Value, args []js.Value) any {
			programID, idOK := stringArgument(args, 0)
			if !idOK {
				return invalidRequestValue()
			}
			return celbridge.ReleaseProgram(programID)
		}),
		js.FuncOf(func(js.Value, []js.Value) any { return celbridge.Close() }),
		js.FuncOf(func(_ js.Value, args []js.Value) any {
			options, optionsOK := optionalStringArgument(args, 0)
			if !optionsOK {
				return invalidRequestValue()
			}
			return celbridge.Create(options)
		}),
		js.FuncOf(func(_ js.Value, args []js.Value) any {
			request, requestOK := stringArgument(args, 0)
			if !requestOK {
				return invalidRequestValue()
			}
			return celbridge.Call(request)
		}),
	)
	js.Global().Set("celBridgeVersion", functions[0])
	js.Global().Set("celBridgeRuntimeInfo", functions[1])
	js.Global().Set("celBridgeValidate", functions[2])
	js.Global().Set("celBridgeEvaluate", functions[3])
	js.Global().Set("celBridgeEvaluateMany", functions[4])
	js.Global().Set("celBridgeEvaluateRequests", functions[5])
	js.Global().Set("celBridgePrepare", functions[6])
	js.Global().Set("celBridgeEvaluateProgram", functions[7])
	js.Global().Set("celBridgeReleaseProgram", functions[8])
	js.Global().Set("celBridgeClose", functions[9])
	js.Global().Set("celBridgeCreate", functions[10])
	js.Global().Set("celBridgeCall", functions[11])
	js.Global().Set("celBridgeReady", true)

	select {}
}
