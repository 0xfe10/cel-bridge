//go:build js && wasm

package main

import (
	"syscall/js"

	"github.com/0xfe10/cel-bridge/celbridge"
	"github.com/0xfe10/cel-bridge/internal/protocol"
)

var functions []js.Func

func stringArgument(args []js.Value, index int) (string, bool) {
	if index >= len(args) || args[index].Type() != js.TypeString {
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
			if !environmentOK || !sourceOK {
				return invalidRequestValue()
			}
			return celbridge.Validate(environment, source)
		}),
		js.FuncOf(func(_ js.Value, args []js.Value) any {
			environment, environmentOK := stringArgument(args, 0)
			source, sourceOK := stringArgument(args, 1)
			variables, variablesOK := stringArgument(args, 2)
			if !environmentOK || !sourceOK || !variablesOK {
				return invalidRequestValue()
			}
			return celbridge.Evaluate(environment, source, variables)
		}),
	)
	js.Global().Set("celBridgeVersion", functions[0])
	js.Global().Set("celBridgeRuntimeInfo", functions[1])
	js.Global().Set("celBridgeValidate", functions[2])
	js.Global().Set("celBridgeEvaluate", functions[3])
	js.Global().Set("celBridgeReady", true)

	select {}
}
