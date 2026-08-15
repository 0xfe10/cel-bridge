package environment

import (
	"encoding/json"
	"fmt"
	"io"
	"strings"
)

type rawEnvironment struct {
	SchemaVersion *int                   `json:"schemaVersion"`
	Variables     map[string]rawTypeSpec `json:"variables"`
}

type rawTypeSpec struct {
	Type    string       `json:"type"`
	Element *rawTypeSpec `json:"element"`
	Key     *rawTypeSpec `json:"key"`
	Value   *rawTypeSpec `json:"value"`
}

func Decode(raw string, maxDepth int) (Environment, error) {
	decoder := json.NewDecoder(strings.NewReader(raw))
	decoder.DisallowUnknownFields()
	var input rawEnvironment
	if err := decoder.Decode(&input); err != nil {
		return Environment{}, fmt.Errorf("invalid environment JSON: %w", err)
	}
	var trailing any
	if err := decoder.Decode(&trailing); err != io.EOF {
		if err == nil {
			return Environment{}, fmt.Errorf("environment JSON contains trailing data")
		}
		return Environment{}, fmt.Errorf("invalid trailing environment JSON: %w", err)
	}
	if input.SchemaVersion == nil || *input.SchemaVersion != 1 {
		return Environment{}, fmt.Errorf("schemaVersion must be 1")
	}
	if input.Variables == nil {
		return Environment{}, fmt.Errorf("variables must be an object")
	}

	result := Environment{SchemaVersion: 1, Variables: make(map[string]TypeSpec, len(input.Variables))}
	for name, rawType := range input.Variables {
		if !validIdentifier(name) {
			return Environment{}, fmt.Errorf("invalid CEL variable name %q", name)
		}
		if _, exists := result.Variables[name]; exists {
			return Environment{}, fmt.Errorf("duplicate variable %q", name)
		}
		typeSpec, err := decodeType(rawType, 1, maxDepth)
		if err != nil {
			return Environment{}, fmt.Errorf("variable %q: %w", name, err)
		}
		result.Variables[name] = typeSpec
	}
	return result, nil
}

func decodeType(raw rawTypeSpec, depth, maxDepth int) (TypeSpec, error) {
	if depth > maxDepth {
		return TypeSpec{}, fmt.Errorf("type nesting exceeds %d levels", maxDepth)
	}
	if raw.Type == "" {
		return TypeSpec{}, fmt.Errorf("type is required")
	}
	spec := TypeSpec{Name: raw.Type}
	switch raw.Type {
	case "null", "bool", "int", "uint", "double", "string", "bytes", "timestamp", "duration", "dyn":
		if raw.Element != nil || raw.Key != nil || raw.Value != nil {
			return TypeSpec{}, fmt.Errorf("scalar type %q cannot have nested types", raw.Type)
		}
	case "list":
		if raw.Element == nil || raw.Key != nil || raw.Value != nil {
			return TypeSpec{}, fmt.Errorf("list requires only element")
		}
		element, err := decodeType(*raw.Element, depth+1, maxDepth)
		if err != nil {
			return TypeSpec{}, err
		}
		spec.Element = &element
	case "map":
		if raw.Key == nil || raw.Value == nil || raw.Element != nil {
			return TypeSpec{}, fmt.Errorf("map requires only key and value")
		}
		key, err := decodeType(*raw.Key, depth+1, maxDepth)
		if err != nil {
			return TypeSpec{}, err
		}
		value, err := decodeType(*raw.Value, depth+1, maxDepth)
		if err != nil {
			return TypeSpec{}, err
		}
		if key.Name == "list" || key.Name == "map" || key.Name == "null" {
			return TypeSpec{}, fmt.Errorf("map key type %q is not supported", key.Name)
		}
		spec.Key, spec.Value = &key, &value
	default:
		return TypeSpec{}, fmt.Errorf("unknown type %q", raw.Type)
	}
	return spec, nil
}
