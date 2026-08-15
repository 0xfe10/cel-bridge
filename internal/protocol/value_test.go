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
      "bytes": {"kind":"bytes","value":"SGVsbG8="},
      "timestamp": {"kind":"timestamp","value":"2026-08-15T10:00:00Z"},
      "duration": {"kind":"duration","value":"1.5s"}
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
	if _, err := DecodeVariables(`{"age":{"kind":"int","value":true}}`, 1024, 8); err == nil {
		t.Fatal("invalid tagged value was accepted")
	}
}

func TestDecodeVariablesSupportsTaggedMapKeys(t *testing.T) {
	variables, err := DecodeVariables(`{
      "values": {"kind":"map","entries":[
        {"key":{"kind":"int","value":"1"},"value":"one"}
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
