package celtype

import (
	"bytes"
	"encoding/json"
	"fmt"
	"strings"

	"github.com/google/cel-go/cel"
	"github.com/google/cel-go/common/types"

	"github.com/0xfe10/cel-bridge/runtime/internal/environment"
	"github.com/0xfe10/cel-bridge/runtime/internal/protocol"
)

type Options struct {
	Expected   *environment.TypeSpec
	DeadlineMs *int64
}

func ParseOptions(raw string) (Options, error) {
	trimmed := strings.TrimSpace(raw)
	if trimmed == "" {
		return Options{}, nil
	}
	decoder := json.NewDecoder(strings.NewReader(trimmed))
	decoder.DisallowUnknownFields()
	var parsed struct {
		Expected   json.RawMessage `json:"expectedResultType"`
		DeadlineMs *int64          `json:"deadlineMs"`
	}
	if err := decoder.Decode(&parsed); err != nil {
		return Options{}, fmt.Errorf("invalid request options: %w", err)
	}
	if decoder.More() {
		return Options{}, fmt.Errorf("request options JSON contains trailing data")
	}
	if parsed.DeadlineMs != nil && *parsed.DeadlineMs < 0 {
		return Options{}, fmt.Errorf("deadlineMs must be >= 0")
	}
	if len(bytes.TrimSpace(parsed.Expected)) == 0 {
		return Options{DeadlineMs: parsed.DeadlineMs}, nil
	}
	spec, err := Parse(parsed.Expected)
	if err != nil {
		return Options{}, err
	}
	return Options{Expected: &spec, DeadlineMs: parsed.DeadlineMs}, nil
}

func (o Options) Deadline() Deadline {
	if o.DeadlineMs == nil {
		return Deadline{}
	}
	return NewDeadline(*o.DeadlineMs)
}

func Parse(raw json.RawMessage) (environment.TypeSpec, error) {
	raw = bytes.TrimSpace(raw)
	if len(raw) == 0 || bytes.Equal(raw, []byte("null")) {
		return environment.TypeSpec{}, fmt.Errorf("expectedResultType is required")
	}
	if raw[0] == '"' {
		var name string
		if err := json.Unmarshal(raw, &name); err != nil {
			return environment.TypeSpec{}, fmt.Errorf("invalid expectedResultType: %w", err)
		}
		return parseName(name)
	}
	var ref protocol.TypeRef
	if err := json.Unmarshal(raw, &ref); err != nil {
		return environment.TypeSpec{}, fmt.Errorf("invalid expectedResultType: %w", err)
	}
	return fromRef(ref)
}

func parseName(name string) (environment.TypeSpec, error) {
	switch name {
	case "null", "bool", "int", "uint", "double", "string", "bytes", "timestamp", "duration", "dyn":
		return environment.TypeSpec{Name: name}, nil
	default:
		return environment.TypeSpec{}, fmt.Errorf("unknown expectedResultType %q", name)
	}
}

func fromRef(ref protocol.TypeRef) (environment.TypeSpec, error) {
	spec := environment.TypeSpec{Name: ref.Type}
	switch ref.Type {
	case "null", "bool", "int", "uint", "double", "string", "bytes", "timestamp", "duration", "dyn":
		if ref.Element != nil || ref.Key != nil || ref.Value != nil {
			return environment.TypeSpec{}, fmt.Errorf("scalar type %q cannot have nested types", ref.Type)
		}
		return spec, nil
	case "list":
		if ref.Element == nil || ref.Key != nil || ref.Value != nil {
			return environment.TypeSpec{}, fmt.Errorf("list requires only element")
		}
		element, err := fromRef(*ref.Element)
		if err != nil {
			return environment.TypeSpec{}, err
		}
		spec.Element = &element
		return spec, nil
	case "map":
		if ref.Key == nil || ref.Value == nil || ref.Element != nil {
			return environment.TypeSpec{}, fmt.Errorf("map requires only key and value")
		}
		key, err := fromRef(*ref.Key)
		if err != nil {
			return environment.TypeSpec{}, err
		}
		value, err := fromRef(*ref.Value)
		if err != nil {
			return environment.TypeSpec{}, err
		}
		spec.Key, spec.Value = &key, &value
		return spec, nil
	default:
		return environment.TypeSpec{}, fmt.Errorf("unknown expectedResultType %q", ref.Type)
	}
}

func FromCEL(t *cel.Type) environment.TypeSpec {
	if t == nil {
		return environment.TypeSpec{Name: "dyn"}
	}
	switch t.Kind() {
	case types.BoolKind:
		return environment.TypeSpec{Name: "bool"}
	case types.IntKind:
		return environment.TypeSpec{Name: "int"}
	case types.UintKind:
		return environment.TypeSpec{Name: "uint"}
	case types.DoubleKind:
		return environment.TypeSpec{Name: "double"}
	case types.StringKind:
		return environment.TypeSpec{Name: "string"}
	case types.BytesKind:
		return environment.TypeSpec{Name: "bytes"}
	case types.TimestampKind:
		return environment.TypeSpec{Name: "timestamp"}
	case types.DurationKind:
		return environment.TypeSpec{Name: "duration"}
	case types.NullTypeKind:
		return environment.TypeSpec{Name: "null"}
	case types.ListKind:
		element := environment.TypeSpec{Name: "dyn"}
		if params := t.Parameters(); len(params) > 0 {
			element = FromCEL(params[0])
		}
		return environment.TypeSpec{Name: "list", Element: &element}
	case types.MapKind:
		key := environment.TypeSpec{Name: "dyn"}
		value := environment.TypeSpec{Name: "dyn"}
		if params := t.Parameters(); len(params) > 0 {
			key = FromCEL(params[0])
			if len(params) > 1 {
				value = FromCEL(params[1])
			}
		}
		return environment.TypeSpec{Name: "map", Key: &key, Value: &value}
	default:
		return environment.TypeSpec{Name: "dyn"}
	}
}

// Compatible reports whether actual can satisfy expected at compile time.
// needsRuntime is true when the static type is dyn (or contains dyn) so the
// result must be checked after evaluation.
func Compatible(actual, expected environment.TypeSpec) (ok bool, needsRuntime bool) {
	if expected.Name == "dyn" {
		return true, false
	}
	if containsDyn(actual) {
		return true, true
	}
	return assignable(actual, expected), false
}

func containsDyn(spec environment.TypeSpec) bool {
	if spec.Name == "dyn" {
		return true
	}
	if spec.Element != nil && containsDyn(*spec.Element) {
		return true
	}
	if spec.Key != nil && containsDyn(*spec.Key) {
		return true
	}
	if spec.Value != nil && containsDyn(*spec.Value) {
		return true
	}
	return false
}

func assignable(actual, expected environment.TypeSpec) bool {
	if expected.Name == "dyn" {
		return true
	}
	if actual.Name != expected.Name {
		return false
	}
	switch expected.Name {
	case "list":
		if expected.Element == nil {
			return true
		}
		if actual.Element == nil {
			return expected.Element.Name == "dyn"
		}
		return assignable(*actual.Element, *expected.Element)
	case "map":
		if expected.Key == nil || expected.Value == nil {
			return true
		}
		if actual.Key == nil || actual.Value == nil {
			return expected.Key.Name == "dyn" && expected.Value.Name == "dyn"
		}
		return assignable(*actual.Key, *expected.Key) && assignable(*actual.Value, *expected.Value)
	default:
		return true
	}
}

func MatchesValue(expected environment.TypeSpec, value protocol.Value) bool {
	if expected.Name == "dyn" {
		return true
	}
	if expected.Name != value.Kind {
		return false
	}
	switch expected.Name {
	case "list":
		if value.Items == nil {
			return false
		}
		if expected.Element == nil || expected.Element.Name == "dyn" {
			return true
		}
		for _, item := range *value.Items {
			if !MatchesValue(*expected.Element, item) {
				return false
			}
		}
		return true
	case "map":
		if value.Entries == nil {
			return false
		}
		for _, entry := range *value.Entries {
			if expected.Key != nil && expected.Key.Name != "dyn" && !MatchesValue(*expected.Key, entry.Key) {
				return false
			}
			if expected.Value != nil && expected.Value.Name != "dyn" && !MatchesValue(*expected.Value, entry.Value) {
				return false
			}
		}
		return true
	default:
		return true
	}
}

func MismatchMessage(expected, actual string) string {
	return fmt.Sprintf("expected %s but evaluation produced %s", expected, actual)
}

func StaticMismatchMessage(expected, actual string) string {
	return fmt.Sprintf("expected %s but static type is %s", expected, actual)
}
