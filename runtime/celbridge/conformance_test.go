package celbridge

import (
	"encoding/json"
	"os"
	"path/filepath"
	"reflect"
	"runtime"
	"testing"
)

type conformanceCase struct {
	Name        string          `json:"name"`
	Environment json.RawMessage `json:"environment"`
	Source      string          `json:"source"`
	Variables   json.RawMessage `json:"variables"`
	Expected    map[string]any  `json:"expected"`
}

type errorCase struct {
	Name        string          `json:"name"`
	Environment json.RawMessage `json:"environment"`
	Source      string          `json:"source"`
	Variables   json.RawMessage `json:"variables"`
	Operation   string          `json:"operation"`
	Expected    string          `json:"expectedCode"`
}

func TestSharedConformanceCases(t *testing.T) {
	cases := loadCases(t, "conformance_cases.json")
	for _, testCase := range cases {
		t.Run(testCase.Name, func(t *testing.T) {
			response := decode(t, Evaluate(
				string(testCase.Environment),
				testCase.Source,
				string(testCase.Variables),
			))
			if response["ok"] != true {
				t.Fatalf("evaluation failed: %#v", response)
			}
			if !reflect.DeepEqual(response["result"], testCase.Expected) {
				t.Fatalf("expected %#v, got %#v", testCase.Expected, response["result"])
			}
		})
	}
}

func TestSharedErrorCases(t *testing.T) {
	cases := loadErrorCases(t)
	for _, testCase := range cases {
		t.Run(testCase.Name, func(t *testing.T) {
			var response map[string]any
			if testCase.Operation == "validate" {
				response = decode(t, Validate(string(testCase.Environment), testCase.Source))
				if response["ok"] != true {
					t.Fatalf("validation request failed: %#v", response)
				}
				result := response["result"].(map[string]any)
				issues := result["issues"].([]any)
				if len(issues) == 0 || issues[0].(map[string]any)["code"] != testCase.Expected {
					t.Fatalf("expected issue %q, got %#v", testCase.Expected, response)
				}
				return
			}
			response = decode(t, Evaluate(
				string(testCase.Environment),
				testCase.Source,
				string(testCase.Variables),
			))
			if response["ok"] != false || response["error"].(map[string]any)["code"] != testCase.Expected {
				t.Fatalf("expected error %q, got %#v", testCase.Expected, response)
			}
		})
	}
}

func loadCases(t *testing.T, name string) []conformanceCase {
	t.Helper()
	_, sourceFile, _, ok := runtime.Caller(0)
	if !ok {
		t.Fatal("runtime.Caller failed")
	}
	path := filepath.Join(filepath.Dir(sourceFile), "..", "..", "protocol", "testdata", name)
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	var cases []conformanceCase
	if err := json.Unmarshal(data, &cases); err != nil {
		t.Fatal(err)
	}
	return cases
}

func loadErrorCases(t *testing.T) []errorCase {
	t.Helper()
	_, sourceFile, _, ok := runtime.Caller(0)
	if !ok {
		t.Fatal("runtime.Caller failed")
	}
	path := filepath.Join(filepath.Dir(sourceFile), "..", "..", "protocol", "testdata", "error_cases.json")
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	var cases []errorCase
	if err := json.Unmarshal(data, &cases); err != nil {
		t.Fatal(err)
	}
	return cases
}
