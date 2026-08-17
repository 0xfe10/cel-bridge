package celbridge

import (
	"encoding/json"
	"testing"
)

const emptyEnvironment = `{"schemaVersion":1,"variables":{}}`

func TestValidateAndEvaluate(t *testing.T) {
	validation := decode(t, Validate(emptyEnvironment, `1 + 1 == 2`))
	if validation["ok"] != true {
		t.Fatalf("validation failed: %#v", validation)
	}
	result := decode(t, Evaluate(emptyEnvironment, `1 + 1 == 2`, `{}`))
	if result["ok"] != true {
		t.Fatalf("evaluation failed: %#v", result)
	}
	value := result["result"].(map[string]any)
	if value["kind"] != "bool" || value["value"] != true {
		t.Fatalf("unexpected result: %#v", value)
	}
}

func TestValidationReportsUndeclaredReference(t *testing.T) {
	response := decode(t, Validate(emptyEnvironment, `missing == 1`))
	result := response["result"].(map[string]any)
	issues := result["issues"].([]any)
	if result["valid"] != false || len(issues) == 0 {
		t.Fatalf("unexpected validation: %#v", response)
	}
}

func decode(t *testing.T, raw string) map[string]any {
	t.Helper()
	var value map[string]any
	if err := json.Unmarshal([]byte(raw), &value); err != nil {
		t.Fatalf("invalid JSON %q: %v", raw, err)
	}
	return value
}
