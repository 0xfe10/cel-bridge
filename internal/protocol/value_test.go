package protocol

import (
	"testing"
	"time"
)

func TestDecodeVariablesPreservesIntegerTypes(t *testing.T) {
	variables, err := DecodeVariables(`{"small":1,"large":18446744073709551615,"float":1.5}`, 1024, 8)
	if err != nil {
		t.Fatal(err)
	}
	if _, ok := variables["small"].(int64); !ok {
		t.Fatalf("small has type %T", variables["small"])
	}
	if _, ok := variables["large"].(uint64); !ok {
		t.Fatalf("large has type %T", variables["large"])
	}
}

func TestDecodeVariablesTaggedValues(t *testing.T) {
	variables, err := DecodeVariables(`{
	      "bytes": {"$cel_bridge":true,"kind":"bytes","value":"SGVsbG8="},
	      "timestamp": {"$cel_bridge":true,"kind":"timestamp","value":"2026-08-15T10:00:00Z"},
	      "duration": {"$cel_bridge":true,"kind":"duration","value":"1.5s"}
    }`, 1024, 8)
	if err != nil {
		t.Fatal(err)
	}
	if string(variables["bytes"].([]byte)) != "Hello" {
		t.Fatalf("unexpected bytes: %#v", variables["bytes"])
	}
	if variables["timestamp"].(time.Time).Location() != time.UTC {
		t.Fatalf("timestamp was not normalized to UTC")
	}
	if variables["duration"].(time.Duration) != 1500*time.Millisecond {
		t.Fatalf("unexpected duration: %#v", variables["duration"])
	}
}

func TestDecodeVariablesRejectsTrailingJSON(t *testing.T) {
	if _, err := DecodeVariables(`{} {}`, 1024, 8); err == nil {
		t.Fatal("trailing JSON was accepted")
	}
}

func TestDecodeVariablesRejectsDuplicateKeys(t *testing.T) {
	if _, err := DecodeVariables(`{"age":1,"age":2}`, 1024, 8); err == nil {
		t.Fatal("duplicate variable key was accepted")
	}
}

func TestDecodeVariablesRejectsInvalidTaggedValue(t *testing.T) {
	if _, err := DecodeVariables(`{"age":{"$cel_bridge":true,"kind":"int","value":true}}`, 1024, 8); err == nil {
		t.Fatal("invalid tagged value was accepted")
	}
}

func TestDecodeVariablesRejectsDeepJSONBeforeDecoding(t *testing.T) {
	if _, err := DecodeVariables(`{"value":[[[1]]]}`, 1024, 2); err == nil {
		t.Fatal("deep variables JSON was accepted")
	}
}

func TestDecodeVariablesRejectsDuplicateTaggedMapKeys(t *testing.T) {
	const raw = `{"values":{"$cel_bridge":true,"kind":"map","entries":[
    {"key":{"$cel_bridge":true,"kind":"string","value":"same"},"value":1},
    {"key":{"$cel_bridge":true,"kind":"string","value":"same"},"value":2}
  ]}}`
	if _, err := DecodeVariables(raw, 1024, 8); err == nil {
		t.Fatal("duplicate tagged map key was accepted")
	}
}

func TestDecodeVariablesAllowsKindInOrdinaryMaps(t *testing.T) {
	variables, err := DecodeVariables(
		`{"user":{"kind":"admin","value":"active"}}`,
		1024,
		8,
	)
	if err != nil {
		t.Fatal(err)
	}
	user, ok := variables["user"].(map[string]any)
	if !ok || user["kind"] != "admin" || user["value"] != "active" {
		t.Fatalf("ordinary map was not preserved: %#v", variables["user"])
	}
}

func TestDecodeVariablesSupportsTaggedMapKeys(t *testing.T) {
	variables, err := DecodeVariables(`{
	      "values": {"$cel_bridge":true,"kind":"map","entries":[
	        {"key":{"$cel_bridge":true,"kind":"int","value":"1"},"value":"one"}
      ]}
    }`, 1024, 8)
	if err != nil {
		t.Fatal(err)
	}
	values, ok := variables["values"].(map[any]any)
	if !ok || values[int64(1)] != "one" {
		t.Fatalf("unexpected tagged map: %#v", variables["values"])
	}
}
