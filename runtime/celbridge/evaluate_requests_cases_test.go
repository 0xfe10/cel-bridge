package celbridge

import (
	"encoding/json"
	"os"
	"path/filepath"
	"runtime"
	"testing"
)

type evaluateRequestsCase struct {
	Name         string          `json:"name"`
	Environment  json.RawMessage `json:"environment"`
	Requests     json.RawMessage `json:"requests"`
	OK           bool            `json:"ok"`
	ExpectedCode string          `json:"expectedCode"`
	Results      []struct {
		ID           string          `json:"id"`
		OK           bool            `json:"ok"`
		Expected     json.RawMessage `json:"expected"`
		ExpectedCode string          `json:"expectedCode"`
	} `json:"results"`
}

func TestSharedEvaluateRequestsCases(t *testing.T) {
	_, sourceFile, _, ok := runtime.Caller(0)
	if !ok {
		t.Fatal("runtime.Caller failed")
	}
	path := filepath.Join(filepath.Dir(sourceFile), "..", "..", "protocol", "testdata", "evaluate_requests_cases.json")
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	var cases []evaluateRequestsCase
	if err := json.Unmarshal(data, &cases); err != nil {
		t.Fatal(err)
	}
	if len(cases) == 0 {
		t.Fatal("evaluate requests cases are empty")
	}
	for _, testCase := range cases {
		t.Run(testCase.Name, func(t *testing.T) {
			response := decode(t, EvaluateRequests(string(testCase.Environment), string(testCase.Requests)))
			if !testCase.OK {
				if response["ok"] != false || response["error"].(map[string]any)["code"] != testCase.ExpectedCode {
					t.Fatalf("expected error %q, got %#v", testCase.ExpectedCode, response)
				}
				return
			}
			if response["ok"] != true {
				t.Fatalf("batch failed: %#v", response)
			}
			items := response["result"].([]any)
			if len(items) != len(testCase.Results) {
				t.Fatalf("expected %d results, got %#v", len(testCase.Results), items)
			}
			for i, want := range testCase.Results {
				got := items[i].(map[string]any)
				if got["id"] != want.ID {
					t.Fatalf("result %d id: expected %q, got %#v", i, want.ID, got)
				}
				if got["ok"] != want.OK {
					t.Fatalf("result %d ok: expected %v, got %#v", i, want.OK, got)
				}
				if want.ExpectedCode != "" {
					errObj, _ := got["error"].(map[string]any)
					if errObj == nil || errObj["code"] != want.ExpectedCode {
						t.Fatalf("result %d expected error %q, got %#v", i, want.ExpectedCode, got)
					}
					continue
				}
				if !jsonEqual(t, want.Expected, got["result"]) {
					t.Fatalf("result %d expected %s, got %#v", i, want.Expected, got["result"])
				}
			}
		})
	}
}
