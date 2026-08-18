package runtime

import (
	"encoding/json"
	"testing"

	"github.com/0xfe10/cel-bridge/runtime/internal/protocol"
)

func TestValidateReturnsResultType(t *testing.T) {
	response := New(DefaultLimits).Validate(
		`{"schemaVersion":1,"variables":{"enabled":{"type":"bool"},"count":{"type":"int"}}}`,
		`enabled && count > 0`,
	)
	if !response.OK {
		t.Fatalf("validation failed: %#v", response)
	}
	result, ok := response.Result.(protocol.ValidationResult)
	if !ok || !result.Valid || result.ResultType == nil || result.ResultType.Type != "bool" {
		t.Fatalf("unexpected validation: %#v", response.Result)
	}
}

func TestValidateExpectedResultTypeMismatch(t *testing.T) {
	response := New(DefaultLimits).Validate(
		`{"schemaVersion":1,"variables":{"count":{"type":"int"}}}`,
		`count`,
		`{"expectedResultType":"bool"}`,
	)
	if !response.OK {
		t.Fatalf("validation request failed: %#v", response)
	}
	result := response.Result.(protocol.ValidationResult)
	if result.Valid || result.ResultType == nil || result.ResultType.Type != "int" {
		t.Fatalf("unexpected validation: %#v", result)
	}
	if len(result.Issues) == 0 || result.Issues[0].Code != "result_type_mismatch" {
		t.Fatalf("unexpected issues: %#v", result.Issues)
	}
}

func TestEvaluateExpectedResultTypeRuntimeMismatch(t *testing.T) {
	env := `{"schemaVersion":1,"variables":{"value":{"type":"dyn"}}}`
	response := New(DefaultLimits).Evaluate(env, `value`, `{"value":"yes"}`, `{"expectedResultType":"bool"}`)
	if response.OK || response.Error == nil || response.Error.Code != "result_type_mismatch" {
		t.Fatalf("unexpected response: %#v", response)
	}
}

func TestEvaluateExpectedResultTypeSuccess(t *testing.T) {
	env := `{"schemaVersion":1,"variables":{"enabled":{"type":"bool"}}}`
	response := New(DefaultLimits).Evaluate(env, `enabled`, `{"enabled":true}`, `{"expectedResultType":"bool"}`)
	if !response.OK {
		t.Fatalf("evaluation failed: %#v", response)
	}
}

func TestGenericVariableNamesAreUnspecial(t *testing.T) {
	env := `{
	  "schemaVersion":1,
	  "variables":{
	    "session":{"type":"int"},
	    "foo":{"type":"int"}
	  }
	}`
	left := New(DefaultLimits).Evaluate(env, `session + 1`, `{"session":1,"foo":1}`)
	right := New(DefaultLimits).Evaluate(env, `foo + 1`, `{"session":1,"foo":1}`)
	if !left.OK || !right.OK {
		t.Fatalf("evaluation failed: %#v %#v", left, right)
	}
	if left.Result.(protocol.Value).Value != right.Result.(protocol.Value).Value {
		t.Fatalf("session was treated differently from foo: %#v %#v", left.Result, right.Result)
	}
}

func TestValidateListResultType(t *testing.T) {
	response := New(DefaultLimits).Validate(
		`{"schemaVersion":1,"variables":{"items":{"type":"list","element":{"type":"int"}}}}`,
		`items`,
	)
	result := response.Result.(protocol.ValidationResult)
	if !result.Valid || result.ResultType == nil || result.ResultType.Type != "list" {
		t.Fatalf("unexpected validation: %#v", result)
	}
	encoded, _ := json.Marshal(result.ResultType)
	if string(encoded) != `{"type":"list","element":{"type":"int"}}` {
		t.Fatalf("unexpected resultType JSON: %s", encoded)
	}
}

func TestMissingVariableIsNotNull(t *testing.T) {
	env := `{"schemaVersion":1,"variables":{"value":{"type":"int"}}}`
	missing := New(DefaultLimits).Evaluate(env, `value`, `{}`)
	if missing.OK || missing.Error == nil || missing.Error.Code != "missing_variable" {
		t.Fatalf("missing variable should fail: %#v", missing)
	}
	presentNull := New(DefaultLimits).Evaluate(
		`{"schemaVersion":1,"variables":{"value":{"type":"dyn"}}}`,
		`value == null`,
		`{"value":null}`,
	)
	if !presentNull.OK {
		t.Fatalf("null value should evaluate: %#v", presentNull)
	}
	nullType := New(DefaultLimits).Validate(`{"schemaVersion":1,"variables":{}}`, `null`)
	result := nullType.Result.(protocol.ValidationResult)
	if !result.Valid || result.ResultType == nil || result.ResultType.Type != "null" {
		t.Fatalf("null literal type: %#v", result)
	}
}
