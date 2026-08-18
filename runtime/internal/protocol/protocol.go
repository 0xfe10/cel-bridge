package protocol

import "encoding/json"

const Version = 1
const ABIVersion = 4
const taggedValueMarker = "$cel_bridge"

type Response struct {
	ProtocolVersion int          `json:"protocolVersion"`
	OK              bool         `json:"ok"`
	Result          any          `json:"result,omitempty"`
	Error           *BridgeError `json:"error,omitempty"`
}

type BridgeError struct {
	Code    string  `json:"code"`
	Message string  `json:"message"`
	Issues  []Issue `json:"issues"`
}

type ValidationResult struct {
	Valid      bool     `json:"valid"`
	ResultType *TypeRef `json:"resultType,omitempty"`
	Issues     []Issue  `json:"issues"`
}

// TypeRef is the stable, cross-SDK CEL type encoding used for resultType
// and expectedResultType. Nested list/map types use element/key/value.
type TypeRef struct {
	Type    string   `json:"type"`
	Element *TypeRef `json:"element,omitempty"`
	Key     *TypeRef `json:"key,omitempty"`
	Value   *TypeRef `json:"value,omitempty"`
}

type Issue struct {
	Severity string `json:"severity"`
	Code     string `json:"code"`
	Message  string `json:"message"`
	Line     int    `json:"line,omitempty"`
	Column   int    `json:"column,omitempty"`
}

type RuntimeInfo struct {
	ProtocolVersion int             `json:"protocolVersion"`
	ABIVersion      int             `json:"abiVersion"`
	RuntimeVersion  string          `json:"runtimeVersion"`
	CELGoVersion    string          `json:"celGoVersion"`
	Features        map[string]bool `json:"features"`
	Profiles        []string        `json:"profiles"`
	Limits          map[string]int  `json:"limits"`
}

type RequestResult struct {
	ID     string       `json:"id"`
	OK     bool         `json:"ok"`
	Result any          `json:"result,omitempty"`
	Error  *BridgeError `json:"error,omitempty"`
}

type PrepareResult struct {
	ProgramID string `json:"programId"`
}

type ReleaseResult struct {
	Released bool `json:"released"`
}

type CloseResult struct {
	Closed bool `json:"closed"`
}

type Value struct {
	Kind    string      `json:"kind"`
	Value   any         `json:"value,omitempty"`
	Items   *[]Value    `json:"items,omitempty"`
	Entries *[]MapEntry `json:"entries,omitempty"`
}

type MapEntry struct {
	Key   Value `json:"key"`
	Value Value `json:"value"`
}

func Success(result any) Response {
	return Response{ProtocolVersion: Version, OK: true, Result: result}
}

func Failure(code, message string, issues ...Issue) Response {
	if issues == nil {
		issues = []Issue{}
	}
	return Response{
		ProtocolVersion: Version,
		OK:              false,
		Error:           &BridgeError{Code: code, Message: message, Issues: issues},
	}
}

func JSON(value any) string {
	encoded, err := json.Marshal(value)
	if err != nil {
		return `{"protocolVersion":1,"ok":false,"error":{"code":"internal_error","message":"failed to encode response","issues":[]}}`
	}
	return string(encoded)
}
