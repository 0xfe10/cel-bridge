package environment

import "testing"

func TestDecodeNestedTypes(t *testing.T) {
	value, err := Decode(`{
      "schemaVersion": 1,
      "variables": {
        "age": {"type": "int"},
        "tags": {"type": "list", "element": {"type": "string"}},
        "attributes": {"type": "map", "key": {"type": "string"}, "value": {"type": "dyn"}}
      }
    }`, 16)
	if err != nil {
		t.Fatal(err)
	}
	if len(value.Variables) != 3 || value.Variables["tags"].Element.Name != "string" {
		t.Fatalf("unexpected environment: %#v", value)
	}
}

func TestDecodeRejectsInvalidEnvironment(t *testing.T) {
	cases := []string{
		`{"schemaVersion":2,"variables":{}}`,
		`{"schemaVersion":1,"variables":{"1age":{"type":"int"}}}`,
		`{"schemaVersion":1,"variables":{"items":{"type":"list"}}}`,
		`{"schemaVersion":1,"variables":{"value":{"type":"unknown"}}}`,
		`{"schemaVersion":1,"variables":{"value":null}}`,
		`{"schemaVersion":1,"variables":{"age":{"type":"int"},"age":{"type":"string"}}}`,
		`{"schemaVersion":1,"variables":{"age":{"type":"int","type":"string"}}}`,
		`{"schemaVersion":1,"variables":{"items":{"type":"list","element":{"type":"int","type":"string"}}}}`,
	}
	for _, input := range cases {
		if _, err := Decode(input, 16); err == nil {
			t.Errorf("Decode(%s) succeeded", input)
		}
	}
}
