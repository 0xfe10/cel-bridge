package celbridge

import (
	"encoding/json"
	"testing"
)

func TestCallDispatchesEvaluateRequests(t *testing.T) {
	raw := Call(`{
	  "op":"evaluateRequests",
	  "environment":{"schemaVersion":1,"variables":{"n":{"type":"int"}}},
	  "requests":[{"id":"one","source":"n > 0","variables":{"n":2},"expectedResultType":"bool"}]
	}`)
	var response map[string]any
	if err := json.Unmarshal([]byte(raw), &response); err != nil {
		t.Fatal(err)
	}
	if response["ok"] != true {
		t.Fatalf("call failed: %#v", response)
	}
}
