package runtime

import (
	"encoding/json"
	"testing"

	"github.com/0xfe10/cel-bridge/runtime/internal/protocol"
)

const testEnvironment = `{
  "schemaVersion": 1,
  "variables": {
    "age": {"type": "int"},
    "user": {"type": "map", "key": {"type": "string"}, "value": {"type": "dyn"}}
  }
}`

func TestEvaluateVariablesAndMacros(t *testing.T) {
	response := New(DefaultLimits).Evaluate(testEnvironment, `age >= 18 && user["country"] in ["CN", "SG"]`, `{"age":20,"user":{"country":"CN"}}`)
	if !response.OK {
		t.Fatalf("evaluation failed: %#v", response)
	}
	value := response.Result.(protocol.Value).Kind
	if value != "bool" {
		t.Fatalf("unexpected result kind: %s", value)
	}
}

func TestEvaluateReportsCostLimit(t *testing.T) {
	limits := DefaultLimits
	limits.MaxCost = 0
	response := New(limits).Evaluate(`{"schemaVersion":1,"variables":{}}`, `1 + 1`, `{}`)
	if response.OK || response.Error == nil || response.Error.Code != "cost_limit_exceeded" {
		t.Fatalf("unexpected response: %#v", response)
	}
}

func TestValidateReportsIssues(t *testing.T) {
	response := New(DefaultLimits).Validate(`{"schemaVersion":1,"variables":{}}`, `missing == true`)
	if !response.OK {
		t.Fatalf("validation request failed: %#v", response)
	}
	result, ok := response.Result.(protocol.ValidationResult)
	if !ok || result.Valid || len(result.Issues) == 0 {
		t.Fatalf("unexpected validation: %#v", response)
	}
}

func TestJSONCapsOutput(t *testing.T) {
	limits := DefaultLimits
	limits.MaxOutputBytes = 10
	encoded := New(limits).JSON(New(limits).Evaluate(`{"schemaVersion":1,"variables":{}}`, `true`, `{}`))
	var response map[string]any
	if err := json.Unmarshal([]byte(encoded), &response); err != nil {
		t.Fatal(err)
	}
	if response["ok"] != false {
		t.Fatalf("unexpected response: %s", encoded)
	}
}
