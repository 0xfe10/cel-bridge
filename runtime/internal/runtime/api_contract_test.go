package runtime

import (
	"encoding/json"
	"sync"
	"testing"

	"github.com/0xfe10/cel-bridge/runtime/internal/protocol"
)

func TestEvaluateRequestsIndependentVariables(t *testing.T) {
	runtime := New(DefaultLimits)
	response := runtime.EvaluateRequests(
		`{"schemaVersion":1,"variables":{"enabled":{"type":"bool"},"count":{"type":"int"}}}`,
		`[
		  {"id":"condition-1","source":"enabled && count > 0","variables":{"enabled":true,"count":2},"expectedResultType":"bool"},
		  {"id":"condition-2","source":"count == 0","variables":{"enabled":false,"count":0},"expectedResultType":"bool"}
		]`,
		"",
	)
	if !response.OK {
		t.Fatalf("batch failed: %#v", response)
	}
	results := requestResults(t, response)
	if len(results) != 2 || results[0].ID != "condition-1" || results[1].ID != "condition-2" {
		t.Fatalf("unexpected ids: %#v", results)
	}
	if !results[0].OK || !results[1].OK {
		t.Fatalf("unexpected results: %#v", results)
	}
}

func TestEvaluateRequestsPartialFailureKeepsOrder(t *testing.T) {
	runtime := New(DefaultLimits)
	response := runtime.EvaluateRequests(
		`{"schemaVersion":1,"variables":{"age":{"type":"int"}}}`,
		`[
		  {"id":"ok","source":"age >= 18","variables":{"age":20}},
		  {"id":"bad","source":"missing == 1","variables":{"age":20}},
		  {"id":"later","source":"age >= 21","variables":{"age":20}}
		]`,
		"",
	)
	results := requestResults(t, response)
	if len(results) != 3 || results[0].ID != "ok" || results[1].ID != "bad" || results[2].ID != "later" {
		t.Fatalf("order/id mismatch: %#v", results)
	}
	if !results[0].OK || results[1].OK || results[1].Error == nil || results[1].Error.Code != "compile_error" || !results[2].OK {
		t.Fatalf("unexpected partial failure: %#v", results)
	}
}

func TestEvaluateRequestsRejectsDuplicateIDs(t *testing.T) {
	runtime := New(DefaultLimits)
	response := runtime.EvaluateRequests(
		`{"schemaVersion":1,"variables":{}}`,
		`[{"id":"a","source":"true","variables":{}},{"id":"a","source":"false","variables":{}}]`,
		"",
	)
	if response.OK || response.Error == nil || response.Error.Code != "invalid_request" {
		t.Fatalf("expected invalid_request: %#v", response)
	}
}

func TestPrepareEvaluateReleaseProgram(t *testing.T) {
	runtime := New(DefaultLimits)
	prepared := runtime.Prepare(
		`{"schemaVersion":1,"variables":{"enabled":{"type":"bool"}}}`,
		`enabled`,
		`{"expectedResultType":"bool"}`,
	)
	if !prepared.OK {
		t.Fatalf("prepare failed: %#v", prepared)
	}
	id := prepared.Result.(protocol.PrepareResult).ProgramID
	value := runtime.EvaluateProgram(id, `{"enabled":true}`, "")
	if !value.OK {
		t.Fatalf("evaluateProgram failed: %#v", value)
	}
	released := runtime.ReleaseProgram(id)
	if !released.OK {
		t.Fatalf("release failed: %#v", released)
	}
	missing := runtime.EvaluateProgram(id, `{"enabled":true}`, "")
	if missing.OK || missing.Error == nil || missing.Error.Code != "program_not_found" {
		t.Fatalf("expected program_not_found: %#v", missing)
	}
}

func TestRuntimeCloseIsIdempotent(t *testing.T) {
	runtime := New(DefaultLimits)
	first := runtime.Close()
	second := runtime.Close()
	if !first.OK || !second.OK {
		t.Fatalf("close should be idempotent: %#v %#v", first, second)
	}
	after := runtime.Evaluate(`{"schemaVersion":1,"variables":{}}`, `true`, `{}`)
	if after.OK || after.Error == nil || after.Error.Code != "runtime_closed" {
		t.Fatalf("expected runtime_closed: %#v", after)
	}
}

func TestDeadlineExceededBeforeEval(t *testing.T) {
	runtime := New(DefaultLimits)
	response := runtime.Evaluate(
		`{"schemaVersion":1,"variables":{}}`,
		`true`,
		`{}`,
		`{"deadlineMs":0}`,
	)
	if response.OK || response.Error == nil || response.Error.Code != "deadline_exceeded" {
		t.Fatalf("expected deadline_exceeded: %#v", response)
	}
}

func TestCompileSingleflight(t *testing.T) {
	runtime := New(DefaultLimits)
	var started sync.WaitGroup
	var wait sync.WaitGroup
	started.Add(32)
	wait.Add(32)
	for i := 0; i < 32; i++ {
		go func() {
			started.Done()
			started.Wait()
			defer wait.Done()
			response := runtime.Evaluate(testEnvironment, `age >= 18`, `{"age":20}`)
			if !response.OK {
				t.Errorf("evaluate failed: %#v", response)
			}
		}()
	}
	wait.Wait()
	if runtime.compiledCount() != 1 {
		t.Fatalf("singleflight compiled %d times", runtime.compiledCount())
	}
}

func TestSafeProfileRejectsLargeSource(t *testing.T) {
	runtime := NewProfile(ProfileSafe, SafeLimits)
	big := make([]byte, SafeLimits.MaxSourceBytes+1)
	for i := range big {
		big[i] = 'a'
	}
	response := runtime.Evaluate(`{"schemaVersion":1,"variables":{}}`, string(big), `{}`)
	if response.OK || response.Error == nil || response.Error.Code != "source_too_large" {
		t.Fatalf("safe profile should reject large source: %#v", response)
	}
}

func TestEvaluateRequestsUsesPreparedProgram(t *testing.T) {
	runtime := New(DefaultLimits)
	prepared := runtime.Prepare(
		`{"schemaVersion":1,"variables":{"n":{"type":"int"}}}`,
		`n > 0`,
		`{"expectedResultType":"bool"}`,
	)
	id := prepared.Result.(protocol.PrepareResult).ProgramID
	payload, _ := json.Marshal([]map[string]any{{
		"id":        "one",
		"programId": id,
		"variables": map[string]any{"n": 2},
	}})
	response := runtime.EvaluateRequests(`{"schemaVersion":1,"variables":{"n":{"type":"int"}}}`, string(payload), "")
	results := requestResults(t, response)
	if len(results) != 1 || !results[0].OK {
		t.Fatalf("prepared program batch failed: %#v", response)
	}
}

func TestEvaluateRequestsUsesBatchExpectedType(t *testing.T) {
	runtime := New(DefaultLimits)
	response := runtime.EvaluateRequests(
		`{"schemaVersion":1,"variables":{"n":{"type":"int"}}}`,
		`[{"id":"one","source":"n > 0","variables":{"n":2}}]`,
		`{"expectedResultType":"bool"}`,
	)
	results := requestResults(t, response)
	if len(results) != 1 || !results[0].OK {
		t.Fatalf("batch expected type should apply: %#v", response)
	}
}

func requestResults(t *testing.T, response protocol.Response) []protocol.RequestResult {
	t.Helper()
	if !response.OK {
		t.Fatalf("request batch failed: %#v", response)
	}
	switch value := response.Result.(type) {
	case []protocol.RequestResult:
		return value
	default:
		t.Fatalf("unexpected result type %T", response.Result)
		return nil
	}
}
