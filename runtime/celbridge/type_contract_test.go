package celbridge

import (
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"reflect"
	"runtime"
	"testing"
)

type typeContractCase struct {
	Name               string          `json:"name"`
	Operation          string          `json:"operation"`
	Environment        json.RawMessage `json:"environment"`
	Source             string          `json:"source"`
	Variables          json.RawMessage `json:"variables"`
	ExpectedResultType json.RawMessage `json:"expectedResultType"`
	Valid              *bool           `json:"valid"`
	ResultType         json.RawMessage `json:"resultType"`
	OK                 *bool           `json:"ok"`
	Expected           json.RawMessage `json:"expected"`
	ExpectedCode       string          `json:"expectedCode"`
}

func TestSharedTypeContractCases(t *testing.T) {
	_, sourceFile, _, ok := runtime.Caller(0)
	if !ok {
		t.Fatal("runtime.Caller failed")
	}
	path := filepath.Join(filepath.Dir(sourceFile), "..", "..", "protocol", "testdata", "type_contract_cases.json")
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	var cases []typeContractCase
	if err := json.Unmarshal(data, &cases); err != nil {
		t.Fatal(err)
	}
	if len(cases) == 0 {
		t.Fatal("type contract cases are empty")
	}
	for _, testCase := range cases {
		t.Run(testCase.Name, func(t *testing.T) {
			options := optionsJSON(testCase.ExpectedResultType)
			switch testCase.Operation {
			case "validate":
				response := decode(t, Validate(string(testCase.Environment), testCase.Source, options))
				if response["ok"] != true {
					t.Fatalf("validation request failed: %#v", response)
				}
				result := response["result"].(map[string]any)
				if testCase.Valid != nil && result["valid"] != *testCase.Valid {
					t.Fatalf("expected valid=%v, got %#v", *testCase.Valid, result)
				}
				if len(testCase.ResultType) > 0 && !jsonEqual(t, testCase.ResultType, result["resultType"]) {
					t.Fatalf("expected resultType %s, got %#v", testCase.ResultType, result["resultType"])
				}
				if testCase.ExpectedCode != "" {
					issues := result["issues"].([]any)
					if len(issues) == 0 || issues[0].(map[string]any)["code"] != testCase.ExpectedCode {
						t.Fatalf("expected issue %q, got %#v", testCase.ExpectedCode, result)
					}
				}
			case "evaluate":
				variables := string(testCase.Variables)
				if variables == "" {
					variables = "{}"
				}
				response := decode(t, Evaluate(string(testCase.Environment), testCase.Source, variables, options))
				if testCase.OK != nil && response["ok"] != *testCase.OK {
					t.Fatalf("expected ok=%v, got %#v", *testCase.OK, response)
				}
				if testCase.ExpectedCode != "" {
					if response["ok"] != false || response["error"].(map[string]any)["code"] != testCase.ExpectedCode {
						t.Fatalf("expected error %q, got %#v", testCase.ExpectedCode, response)
					}
					return
				}
				if !jsonEqual(t, testCase.Expected, response["result"]) {
					t.Fatalf("expected %#v, got %#v", testCase.Expected, response["result"])
				}
			default:
				t.Fatalf("unsupported operation %q", testCase.Operation)
			}
		})
	}
}

func optionsJSON(expected json.RawMessage) string {
	if len(bytes.TrimSpace(expected)) == 0 {
		return ""
	}
	return `{"expectedResultType":` + string(expected) + `}`
}

func jsonEqual(t *testing.T, expected json.RawMessage, actual any) bool {
	t.Helper()
	if len(bytes.TrimSpace(expected)) == 0 {
		return true
	}
	var want any
	if err := json.Unmarshal(expected, &want); err != nil {
		t.Fatal(err)
	}
	return reflect.DeepEqual(want, actual)
}
