package environment

import (
	"fmt"
	"unicode"

	"github.com/google/cel-go/cel"
)

type Environment struct {
	SchemaVersion int
	Variables     map[string]TypeSpec
}

type TypeSpec struct {
	Name    string
	Element *TypeSpec
	Key     *TypeSpec
	Value   *TypeSpec
}

func (spec TypeSpec) CELType() (*cel.Type, error) {
	switch spec.Name {
	case "null":
		return cel.NullType, nil
	case "bool":
		return cel.BoolType, nil
	case "int":
		return cel.IntType, nil
	case "uint":
		return cel.UintType, nil
	case "double":
		return cel.DoubleType, nil
	case "string":
		return cel.StringType, nil
	case "bytes":
		return cel.BytesType, nil
	case "timestamp":
		return cel.TimestampType, nil
	case "duration":
		return cel.DurationType, nil
	case "dyn":
		return cel.DynType, nil
	case "list":
		if spec.Element == nil {
			return nil, fmt.Errorf("list type requires element")
		}
		element, err := spec.Element.CELType()
		if err != nil {
			return nil, err
		}
		return cel.ListType(element), nil
	case "map":
		if spec.Key == nil || spec.Value == nil {
			return nil, fmt.Errorf("map type requires key and value")
		}
		key, err := spec.Key.CELType()
		if err != nil {
			return nil, err
		}
		value, err := spec.Value.CELType()
		if err != nil {
			return nil, err
		}
		return cel.MapType(key, value), nil
	default:
		return nil, fmt.Errorf("unknown CEL type %q", spec.Name)
	}
}

func validIdentifier(name string) bool {
	if name == "" || reservedIdentifiers[name] {
		return false
	}
	for index, r := range name {
		if index == 0 {
			if r != '_' && !unicode.IsLetter(r) {
				return false
			}
			continue
		}
		if r != '_' && !unicode.IsLetter(r) && !unicode.IsDigit(r) {
			return false
		}
	}
	return true
}

var reservedIdentifiers = map[string]bool{
	"as": true, "break": true, "const": true, "continue": true,
	"else": true, "false": true, "for": true, "function": true,
	"if": true, "import": true, "in": true, "let": true, "loop": true,
	"namespace": true, "null": true, "package": true, "return": true,
	"true": true, "var": true, "void": true, "while": true,
}
