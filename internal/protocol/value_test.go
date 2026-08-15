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
