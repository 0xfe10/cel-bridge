package environment

import (
	"fmt"

	"github.com/google/cel-go/cel"

	"github.com/0xfe10/cel-bridge/runtime/internal/protocol"
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

func (spec TypeSpec) Format() string {
	switch spec.Name {
	case "list":
		if spec.Element == nil {
			return "list<dyn>"
		}
		return "list<" + spec.Element.Format() + ">"
	case "map":
		key, value := "dyn", "dyn"
		if spec.Key != nil {
			key = spec.Key.Format()
		}
		if spec.Value != nil {
			value = spec.Value.Format()
		}
		return "map<" + key + "," + value + ">"
	default:
		return spec.Name
	}
}

func (spec TypeSpec) Equal(other TypeSpec) bool {
	if spec.Name != other.Name {
		return false
	}
	switch spec.Name {
	case "list":
		if spec.Element == nil || other.Element == nil {
			return spec.Element == nil && other.Element == nil
		}
		return spec.Element.Equal(*other.Element)
	case "map":
		if spec.Key == nil || spec.Value == nil || other.Key == nil || other.Value == nil {
			return spec.Key == nil && other.Key == nil && spec.Value == nil && other.Value == nil
		}
		return spec.Key.Equal(*other.Key) && spec.Value.Equal(*other.Value)
	default:
		return true
	}
}

func (spec TypeSpec) ToRef() protocol.TypeRef {
	ref := protocol.TypeRef{Type: spec.Name}
	if spec.Element != nil {
		element := spec.Element.ToRef()
		ref.Element = &element
	}
	if spec.Key != nil {
		key := spec.Key.ToRef()
		ref.Key = &key
	}
	if spec.Value != nil {
		value := spec.Value.ToRef()
		ref.Value = &value
	}
	return ref
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
			if r != '_' && !asciiLetter(r) {
				return false
			}
			continue
		}
		if r != '_' && !asciiLetter(r) && !asciiDigit(r) {
			return false
		}
	}
	return true
}

func asciiLetter(r rune) bool {
	return r >= 'A' && r <= 'Z' || r >= 'a' && r <= 'z'
}

func asciiDigit(r rune) bool {
	return r >= '0' && r <= '9'
}

var reservedIdentifiers = map[string]bool{
	"as": true, "break": true, "const": true, "continue": true,
	"else": true, "false": true, "for": true, "function": true,
	"if": true, "import": true, "in": true, "let": true, "loop": true,
	"namespace": true, "null": true, "package": true, "return": true,
	"true": true, "var": true, "void": true, "while": true,
}
