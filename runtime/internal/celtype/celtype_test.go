package celtype

import (
	"testing"

	"github.com/0xfe10/cel-bridge/runtime/internal/environment"
	"github.com/0xfe10/cel-bridge/runtime/internal/protocol"
)

func TestParseStringAndObject(t *testing.T) {
	fromString, err := Parse([]byte(`"bool"`))
	if err != nil || fromString.Name != "bool" {
		t.Fatalf("string parse: %#v %v", fromString, err)
	}
	fromObject, err := Parse([]byte(`{"type":"list","element":{"type":"int"}}`))
	if err != nil || fromObject.Format() != "list<int>" {
		t.Fatalf("object parse: %#v %v", fromObject, err)
	}
}

func TestMatchesValue(t *testing.T) {
	expected := environment.TypeSpec{Name: "bool"}
	if !MatchesValue(expected, protocol.Value{Kind: "bool", Value: true}) {
		t.Fatal("bool should match bool")
	}
	if MatchesValue(expected, protocol.Value{Kind: "string", Value: "yes"}) {
		t.Fatal("string should not match bool")
	}
}
