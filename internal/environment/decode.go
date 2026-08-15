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
	input, err := decodeRawEnvironment(decoder, maxDepth)
	if err != nil {
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

func decodeRawEnvironment(decoder *json.Decoder, maxDepth int) (rawEnvironment, error) {
	token, err := decoder.Token()
	if err != nil {
		return rawEnvironment{}, err
	}
	if token != json.Delim('{') {
		return rawEnvironment{}, fmt.Errorf("environment must be an object")
	}
	var input rawEnvironment
	seen := make(map[string]struct{})
	for decoder.More() {
		keyToken, err := decoder.Token()
		if err != nil {
			return rawEnvironment{}, err
		}
		key, ok := keyToken.(string)
		if !ok {
			return rawEnvironment{}, fmt.Errorf("environment object key is not a string")
		}
		if _, exists := seen[key]; exists {
			return rawEnvironment{}, fmt.Errorf("duplicate environment field %q", key)
		}
		seen[key] = struct{}{}
		switch key {
		case "schemaVersion":
			if err := decoder.Decode(&input.SchemaVersion); err != nil {
				return rawEnvironment{}, err
			}
		case "variables":
			variables, err := decodeVariables(decoder, maxDepth)
			if err != nil {
				return rawEnvironment{}, err
			}
			input.Variables = variables
		default:
			return rawEnvironment{}, fmt.Errorf("unknown field %q", key)
		}
	}
	end, err := decoder.Token()
	if err != nil || end != json.Delim('}') {
		return rawEnvironment{}, fmt.Errorf("invalid environment object")
	}
	return input, nil
}

func decodeVariables(
	decoder *json.Decoder,
	maxDepth int,
) (map[string]rawTypeSpec, error) {
	token, err := decoder.Token()
	if err != nil {
		return nil, err
	}
	if token == nil {
		return nil, nil
	}
	if token != json.Delim('{') {
		return nil, fmt.Errorf("variables must be an object")
	}
	variables := make(map[string]rawTypeSpec)
	for decoder.More() {
		keyToken, err := decoder.Token()
		if err != nil {
			return nil, err
		}
		name, ok := keyToken.(string)
		if !ok {
			return nil, fmt.Errorf("variable name is not a string")
		}
		if _, exists := variables[name]; exists {
			return nil, fmt.Errorf("duplicate variable %q", name)
		}
		rawType, err := decodeRawTypeSpec(decoder, 1, maxDepth)
		if err != nil {
			return nil, err
		}
		if rawType == nil {
			variables[name] = rawTypeSpec{}
		} else {
			variables[name] = *rawType
		}
	}
	end, err := decoder.Token()
	if err != nil || end != json.Delim('}') {
		return nil, fmt.Errorf("invalid variables object")
	}
	return variables, nil
}

func decodeRawTypeSpec(
	decoder *json.Decoder,
	depth, maxDepth int,
) (*rawTypeSpec, error) {
	if depth > maxDepth {
		return nil, fmt.Errorf("type nesting exceeds %d levels", maxDepth)
	}
	token, err := decoder.Token()
	if err != nil {
		return nil, err
	}
	if token == nil {
		return nil, nil
	}
	if token != json.Delim('{') {
		return nil, fmt.Errorf("type specification must be an object")
	}
	raw := &rawTypeSpec{}
	seen := make(map[string]struct{})
	for decoder.More() {
		keyToken, err := decoder.Token()
		if err != nil {
			return nil, err
		}
		key, ok := keyToken.(string)
		if !ok {
			return nil, fmt.Errorf("type specification key is not a string")
		}
		if _, exists := seen[key]; exists {
			return nil, fmt.Errorf("duplicate type field %q", key)
		}
		seen[key] = struct{}{}
		switch key {
		case "type":
			if err := decoder.Decode(&raw.Type); err != nil {
				return nil, err
			}
		case "element":
			raw.Element, err = decodeRawTypeSpec(decoder, depth+1, maxDepth)
			if err != nil {
				return nil, err
			}
		case "key":
			raw.Key, err = decodeRawTypeSpec(decoder, depth+1, maxDepth)
			if err != nil {
				return nil, err
			}
		case "value":
			raw.Value, err = decodeRawTypeSpec(decoder, depth+1, maxDepth)
			if err != nil {
				return nil, err
			}
		default:
			return nil, fmt.Errorf("unknown type field %q", key)
		}
	}
	end, err := decoder.Token()
	if err != nil || end != json.Delim('}') {
		return nil, fmt.Errorf("invalid type specification")
	}
	return raw, nil
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
