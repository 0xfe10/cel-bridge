package main

/*
#include <stdint.h>
#include <stdlib.h>
typedef struct CelBridgeBuffer {
	uint8_t* data;
	size_t len;
} CelBridgeBuffer;
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

func optionalInput(value *C.char) string {
	if value == nil {
		return ""
	}
	return C.GoString(value)
}

func output(value string) *C.char {
	return C.CString(value)
}

//export cel_bridge_version
func cel_bridge_version() *C.char {
	return output(celbridge.Version())
}

//export cel_bridge_runtime_info
func cel_bridge_runtime_info() *C.char {
	return output(celbridge.RuntimeInfo())
}

//export cel_bridge_validate
func cel_bridge_validate(environmentJSON, source *C.char) *C.char {
	return cel_bridge_validate_options(environmentJSON, source, nil)
}

//export cel_bridge_validate_options
func cel_bridge_validate_options(environmentJSON, source, optionsJSON *C.char) *C.char {
	environment, environmentOK := input(environmentJSON)
	expression, sourceOK := input(source)
	if !environmentOK || !sourceOK {
		return invalidRequest()
	}
	return output(celbridge.Validate(environment, expression, optionalInput(optionsJSON)))
}

//export cel_bridge_evaluate
func cel_bridge_evaluate(environmentJSON, source, variablesJSON *C.char) *C.char {
	return cel_bridge_evaluate_options(environmentJSON, source, variablesJSON, nil)
}

//export cel_bridge_evaluate_options
func cel_bridge_evaluate_options(environmentJSON, source, variablesJSON, optionsJSON *C.char) *C.char {
	environment, environmentOK := input(environmentJSON)
	expression, sourceOK := input(source)
	variables, variablesOK := input(variablesJSON)
	if !environmentOK || !sourceOK || !variablesOK {
		return invalidRequest()
	}
	return output(celbridge.Evaluate(environment, expression, variables, optionalInput(optionsJSON)))
}

//export cel_bridge_evaluate_many
func cel_bridge_evaluate_many(environmentJSON, sourcesJSON, variablesJSON *C.char) *C.char {
	environment, environmentOK := input(environmentJSON)
	sources, sourcesOK := input(sourcesJSON)
	variables, variablesOK := input(variablesJSON)
	if !environmentOK || !sourcesOK || !variablesOK {
		return invalidRequest()
	}
	return output(celbridge.EvaluateMany(environment, sources, variables))
}

//export cel_bridge_evaluate_requests
func cel_bridge_evaluate_requests(environmentJSON, requestsJSON, optionsJSON *C.char) *C.char {
	environment, environmentOK := input(environmentJSON)
	requests, requestsOK := input(requestsJSON)
	if !environmentOK || !requestsOK {
		return invalidRequest()
	}
	return output(celbridge.EvaluateRequests(environment, requests, optionalInput(optionsJSON)))
}

//export cel_bridge_prepare
func cel_bridge_prepare(environmentJSON, source, optionsJSON *C.char) *C.char {
	environment, environmentOK := input(environmentJSON)
	expression, sourceOK := input(source)
	if !environmentOK || !sourceOK {
		return invalidRequest()
	}
	return output(celbridge.Prepare(environment, expression, optionalInput(optionsJSON)))
}

//export cel_bridge_evaluate_program
func cel_bridge_evaluate_program(programID, variablesJSON, optionsJSON *C.char) *C.char {
	id, idOK := input(programID)
	variables, variablesOK := input(variablesJSON)
	if !idOK || !variablesOK {
		return invalidRequest()
	}
	return output(celbridge.EvaluateProgram(id, variables, optionalInput(optionsJSON)))
}

//export cel_bridge_release_program
func cel_bridge_release_program(programID *C.char) *C.char {
	id, idOK := input(programID)
	if !idOK {
		return invalidRequest()
	}
	return output(celbridge.ReleaseProgram(id))
}

//export cel_bridge_close
func cel_bridge_close() *C.char {
	return output(celbridge.Close())
}

//export cel_bridge_create
func cel_bridge_create(optionsJSON *C.char) *C.char {
	return output(celbridge.Create(optionalInput(optionsJSON)))
}

//export cel_bridge_call_v2
func cel_bridge_call_v2(request *C.uint8_t, requestLen C.size_t) (buffer C.CelBridgeBuffer) {
	defer func() {
		if recover() != nil {
			encoded := []byte(protocol.JSON(protocol.Failure("internal_error", "runtime panic recovered")))
			buffer = C.CelBridgeBuffer{data: (*C.uint8_t)(C.CBytes(encoded)), len: C.size_t(len(encoded))}
		}
	}()
	var payload []byte
	if request != nil && requestLen > 0 {
		payload = C.GoBytes(unsafe.Pointer(request), C.int(requestLen))
	}
	encoded := []byte(celbridge.Call(string(payload)))
	if len(encoded) == 0 {
		return C.CelBridgeBuffer{}
	}
	return C.CelBridgeBuffer{
		data: (*C.uint8_t)(C.CBytes(encoded)),
		len:  C.size_t(len(encoded)),
	}
}

//export cel_bridge_buffer_free
func cel_bridge_buffer_free(buffer C.CelBridgeBuffer) {
	if buffer.data != nil {
		C.free(unsafe.Pointer(buffer.data))
	}
}

//export cel_bridge_free
func cel_bridge_free(value *C.char) {
	if value != nil {
		C.free(unsafe.Pointer(value))
	}
}

func main() {}
