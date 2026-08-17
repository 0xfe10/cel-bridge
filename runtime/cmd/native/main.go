package main

/*
#include <stdlib.h>
*/
import "C"

import (
	"unsafe"

	"github.com/0xfe10/cel-bridge/runtime/celbridge"
	"github.com/0xfe10/cel-bridge/runtime/internal/protocol"
)

func invalidRequest() *C.char {
	return C.CString(protocol.JSON(protocol.Failure("invalid_request", "C ABI input must not be null")))
}

func input(value *C.char) (string, bool) {
	if value == nil {
		return "", false
	}
	return C.GoString(value), true
}

//export cel_bridge_version
func cel_bridge_version() *C.char {
	return C.CString(celbridge.Version())
}

//export cel_bridge_runtime_info
func cel_bridge_runtime_info() *C.char {
	return C.CString(celbridge.RuntimeInfo())
}

//export cel_bridge_validate
func cel_bridge_validate(environmentJSON, source *C.char) *C.char {
	environment, environmentOK := input(environmentJSON)
	expression, sourceOK := input(source)
	if !environmentOK || !sourceOK {
		return invalidRequest()
	}
	return C.CString(celbridge.Validate(environment, expression))
}

//export cel_bridge_evaluate
func cel_bridge_evaluate(environmentJSON, source, variablesJSON *C.char) *C.char {
	environment, environmentOK := input(environmentJSON)
	expression, sourceOK := input(source)
	variables, variablesOK := input(variablesJSON)
	if !environmentOK || !sourceOK || !variablesOK {
		return invalidRequest()
	}
	return C.CString(celbridge.Evaluate(environment, expression, variables))
}

//export cel_bridge_free
func cel_bridge_free(value *C.char) {
	if value != nil {
		C.free(unsafe.Pointer(value))
	}
}

func main() {}
