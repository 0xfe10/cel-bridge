package protocol

import (
	"bytes"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"math"
	"sort"
	"strconv"
	"strings"
	"time"
	"unicode/utf8"

	"github.com/google/cel-go/common/types"
	"github.com/google/cel-go/common/types/ref"
	"github.com/google/cel-go/common/types/traits"
)

const maxValueDepth = 32
const maxCollectionItems = 4096

func DecodeVariables(raw string, maxBytes, maxDepth int) (map[string]any, error) {
	if len(raw) > maxBytes {
		return nil, fmt.Errorf("variables JSON exceeds %d bytes", maxBytes)
	}
	if !utf8.ValidString(raw) {
		return nil, fmt.Errorf("variables JSON must be valid UTF-8")
	}
	decoder := json.NewDecoder(strings.NewReader(raw))
	decoder.UseNumber()
	decoded, err := decodeJSON(decoder, 0, maxDepth)
	if err != nil {
		return nil, fmt.Errorf("invalid variables JSON: %w", err)
	}
	if _, err := decoder.Token(); err != io.EOF {
		if err == nil {
			return nil, fmt.Errorf("variables JSON contains trailing data")
		}
		return nil, fmt.Errorf("invalid trailing variables JSON: %w", err)
	}
	object, ok := decoded.(map[string]any)
	if !ok {
		return nil, fmt.Errorf("variables JSON must be an object")
	}
	value, err := decodeInput(object, 0, maxDepth)
	if err != nil {
		return nil, err
	}
	return value.(map[string]any), nil
}

func decodeJSON(decoder *json.Decoder, depth, maxDepth int) (any, error) {
	if depth > maxDepth {
		return nil, fmt.Errorf("variables nesting exceeds %d levels", maxDepth)
	}
	token, err := decoder.Token()
	if err != nil {
		return nil, err
	}
	switch token := token.(type) {
	case json.Delim:
		switch token {
		case '{':
			result := make(map[string]any)
			for decoder.More() {
				keyToken, err := decoder.Token()
				if err != nil {
					return nil, err
				}
				key, ok := keyToken.(string)
				if !ok {
					return nil, fmt.Errorf("JSON object key is not a string")
				}
				if _, exists := result[key]; exists {
					return nil, fmt.Errorf("duplicate JSON object key %q", key)
				}
				value, err := decodeJSON(decoder, depth+1, maxDepth)
				if err != nil {
					return nil, err
				}
				result[key] = value
			}
			end, err := decoder.Token()
			if err != nil || end != json.Delim('}') {
				return nil, fmt.Errorf("invalid JSON object")
			}
			return result, nil
		case '[':
			result := make([]any, 0)
			for decoder.More() {
				value, err := decodeJSON(decoder, depth+1, maxDepth)
				if err != nil {
					return nil, err
				}
				result = append(result, value)
			}
			end, err := decoder.Token()
			if err != nil || end != json.Delim(']') {
				return nil, fmt.Errorf("invalid JSON array")
			}
			return result, nil
		default:
			return nil, fmt.Errorf("unexpected JSON delimiter %q", token)
		}
	default:
		return token, nil
	}
}

func decodeInput(value any, depth, maxDepth int) (any, error) {
	if depth > maxDepth {
		return nil, fmt.Errorf("variables nesting exceeds %d levels", maxDepth)
	}
	switch value := value.(type) {
	case nil, bool, string:
		return value, nil
	case json.Number:
		return decodeNumber(value)
	case []any:
		if len(value) > maxCollectionItems {
			return nil, fmt.Errorf("list exceeds %d items", maxCollectionItems)
		}
		result := make([]any, len(value))
		for i, item := range value {
			decoded, err := decodeInput(item, depth+1, maxDepth)
			if err != nil {
				return nil, err
			}
			result[i] = decoded
		}
		return result, nil
	case map[string]any:
		if marker, tagged := value[taggedValueMarker]; tagged {
			if marker != true {
				return nil, fmt.Errorf("tagged value marker must be true")
			}
			return decodeTagged(value, depth, maxDepth)
		}
		if len(value) > maxCollectionItems {
			return nil, fmt.Errorf("map exceeds %d entries", maxCollectionItems)
		}
		result := make(map[string]any, len(value))
		for key, item := range value {
			decoded, err := decodeInput(item, depth+1, maxDepth)
			if err != nil {
				return nil, err
			}
			result[key] = decoded
		}
		return result, nil
	default:
		return nil, fmt.Errorf("unsupported JSON value %T", value)
	}
}

func decodeNumber(value json.Number) (any, error) {
	text := value.String()
	if strings.ContainsAny(text, ".eE") {
		decoded, err := strconv.ParseFloat(text, 64)
		if err != nil || math.IsInf(decoded, 0) || math.IsNaN(decoded) {
			return nil, fmt.Errorf("invalid JSON number %q", text)
		}
		return decoded, nil
	}
	if decoded, err := strconv.ParseInt(text, 10, 64); err == nil {
		return decoded, nil
	}
	if decoded, err := strconv.ParseUint(text, 10, 64); err == nil {
		return decoded, nil
	}
	return nil, fmt.Errorf("integer %q is outside CEL int/uint range", text)
}

func decodeTagged(value map[string]any, depth, maxDepth int) (any, error) {
	kind, ok := value["kind"].(string)
	if !ok {
		return nil, fmt.Errorf("tagged value kind must be a string")
	}
	raw := value["value"]
	switch kind {
	case "null":
		return nil, nil
	case "bool":
		decoded, ok := raw.(bool)
		if !ok {
			return nil, fmt.Errorf("tagged bool value must be a boolean")
		}
		return decoded, nil
	case "int":
		text, ok := raw.(string)
		if !ok {
			return nil, fmt.Errorf("tagged int value must be a string")
		}
		decoded, err := strconv.ParseInt(text, 10, 64)
		if err != nil {
			return nil, fmt.Errorf("invalid tagged int value %q", text)
		}
		return decoded, nil
	case "uint":
		text, ok := raw.(string)
		if !ok {
			return nil, fmt.Errorf("tagged uint value must be a string")
		}
		decoded, err := strconv.ParseUint(text, 10, 64)
		if err != nil {
			return nil, fmt.Errorf("invalid tagged uint value %q", text)
		}
		return decoded, nil
	case "double":
		text, ok := raw.(string)
		if !ok {
			return nil, fmt.Errorf("tagged double value must be a string")
		}
		decoded, err := parseDouble(text)
		if err != nil {
			return nil, fmt.Errorf("invalid tagged double value %q", text)
		}
		return decoded, nil
	case "string":
		decoded, ok := raw.(string)
		if !ok {
			return nil, fmt.Errorf("tagged string value must be a string")
		}
		return decoded, nil
	case "bytes":
		text, ok := raw.(string)
		if !ok {
			return nil, fmt.Errorf("tagged bytes value must be a string")
		}
		decoded, err := base64.StdEncoding.DecodeString(text)
		if err != nil {
			return nil, fmt.Errorf("invalid tagged bytes value: %w", err)
		}
		return decoded, nil
	case "timestamp":
		text, ok := raw.(string)
		if !ok {
			return nil, fmt.Errorf("tagged timestamp value must be a string")
		}
		decoded, err := time.Parse(time.RFC3339Nano, text)
		if err != nil {
			return nil, fmt.Errorf("invalid tagged timestamp value %q", text)
		}
		return decoded.UTC(), nil
	case "duration":
		text, ok := raw.(string)
		if !ok {
			return nil, fmt.Errorf("tagged duration value must be a string")
		}
		decoded, err := time.ParseDuration(text)
		if err != nil {
			return nil, fmt.Errorf("invalid tagged duration value %q", text)
		}
		return decoded, nil
	case "list":
		items, ok := value["items"].([]any)
		if !ok || len(items) > maxCollectionItems {
			return nil, fmt.Errorf("tagged list items are invalid")
		}
		result := make([]any, len(items))
		for i, item := range items {
			decoded, err := decodeInput(item, depth+1, maxDepth)
			if err != nil {
				return nil, err
			}
			result[i] = decoded
		}
		return result, nil
	case "map":
		entries, ok := value["entries"].([]any)
		if !ok || len(entries) > maxCollectionItems {
			return nil, fmt.Errorf("tagged map entries are invalid")
		}
		result := make(map[any]any, len(entries))
		for _, item := range entries {
			entry, ok := item.(map[string]any)
			if !ok {
				return nil, fmt.Errorf("tagged map entry must be an object")
			}
			key, ok := entry["key"]
			if !ok {
				return nil, fmt.Errorf("tagged map entry is missing key")
			}
			entryValue, ok := entry["value"]
			if !ok {
				return nil, fmt.Errorf("tagged map entry is missing value")
			}
			decodedKey, err := decodeInput(key, depth+1, maxDepth)
			if err != nil {
				return nil, err
			}
			switch decodedKey.(type) {
			case bool, int64, uint64, string:
			default:
				return nil, fmt.Errorf("tagged map key type is not supported")
			}
			decodedValue, err := decodeInput(entryValue, depth+1, maxDepth)
			if err != nil {
				return nil, err
			}
			if _, exists := result[decodedKey]; exists {
				return nil, fmt.Errorf("tagged map contains duplicate key")
			}
			result[decodedKey] = decodedValue
		}
		return result, nil
	default:
		return nil, fmt.Errorf("unsupported tagged value kind %q", kind)
	}
}

func parseDouble(value string) (float64, error) {
	switch value {
	case "NaN":
		return math.NaN(), nil
	case "Infinity", "+Infinity", "+Inf":
		return math.Inf(1), nil
	case "-Infinity", "-Inf":
		return math.Inf(-1), nil
	default:
		return strconv.ParseFloat(value, 64)
	}
}

func EncodeValue(value ref.Val) (Value, error) {
	return encodeValue(value, 0)
}

func encodeValue(value ref.Val, depth int) (Value, error) {
	if value == nil {
		return Value{}, fmt.Errorf("nil CEL value")
	}
	if depth > maxValueDepth {
		return Value{}, fmt.Errorf("CEL value nesting exceeds %d levels", maxValueDepth)
	}
	switch value := value.(type) {
	case types.Null:
		return Value{Kind: "null"}, nil
	case types.Bool:
		return Value{Kind: "bool", Value: bool(value)}, nil
	case types.Int:
		return Value{Kind: "int", Value: strconv.FormatInt(int64(value), 10)}, nil
	case types.Uint:
		return Value{Kind: "uint", Value: strconv.FormatUint(uint64(value), 10)}, nil
	case types.Double:
		return Value{Kind: "double", Value: formatDouble(float64(value))}, nil
	case types.String:
		return Value{Kind: "string", Value: string(value)}, nil
	case types.Bytes:
		return Value{Kind: "bytes", Value: base64.StdEncoding.EncodeToString([]byte(value))}, nil
	case types.Timestamp:
		return Value{Kind: "timestamp", Value: value.Time.UTC().Format(time.RFC3339Nano)}, nil
	case types.Duration:
		return Value{Kind: "duration", Value: formatDuration(value.Duration)}, nil
	}
	if list, ok := value.(traits.Lister); ok {
		return encodeList(list, depth)
	}
	if mapper, ok := value.(traits.Mapper); ok {
		return encodeMap(mapper, depth)
	}
	return Value{}, fmt.Errorf("unsupported CEL value type %q", value.Type().TypeName())
}

func encodeList(list traits.Lister, depth int) (Value, error) {
	size, ok := list.Size().(types.Int)
	if !ok || size < 0 || size > maxCollectionItems {
		return Value{}, fmt.Errorf("unsupported CEL list size")
	}
	items := make([]Value, int(size))
	for i := range items {
		item, err := encodeValue(list.Get(types.Int(i)), depth+1)
		if err != nil {
			return Value{}, err
		}
		items[i] = item
	}
	return Value{Kind: "list", Items: &items}, nil
}

func encodeMap(mapper traits.Mapper, depth int) (Value, error) {
	size, ok := mapper.Size().(types.Int)
	if !ok || size < 0 || size > maxCollectionItems {
		return Value{}, fmt.Errorf("unsupported CEL map size")
	}
	entries := make([]MapEntry, 0, int(size))
	iterator := mapper.Iterator()
	for iterator.HasNext() == types.True {
		key := iterator.Next()
		value, found := mapper.Find(key)
		if !found {
			return Value{}, fmt.Errorf("map value disappeared during iteration")
		}
		encodedKey, err := encodeValue(key, depth+1)
		if err != nil {
			return Value{}, err
		}
		encodedValue, err := encodeValue(value, depth+1)
		if err != nil {
			return Value{}, err
		}
		entries = append(entries, MapEntry{Key: encodedKey, Value: encodedValue})
	}
	sort.Slice(entries, func(i, j int) bool {
		left, _ := json.Marshal(entries[i].Key)
		right, _ := json.Marshal(entries[j].Key)
		return bytes.Compare(left, right) < 0
	})
	return Value{Kind: "map", Entries: &entries}, nil
}

func formatDouble(value float64) string {
	switch {
	case math.IsNaN(value):
		return "NaN"
	case math.IsInf(value, 1):
		return "Infinity"
	case math.IsInf(value, -1):
		return "-Infinity"
	default:
		return strconv.FormatFloat(value, 'g', -1, 64)
	}
}

func formatDuration(value time.Duration) string {
	if value == 0 {
		return "0s"
	}
	sign := ""
	magnitude := uint64(value)
	if value < 0 {
		sign = "-"
		magnitude = uint64(-(value + 1)) + 1
	}
	seconds := magnitude / uint64(time.Second)
	nanos := magnitude % uint64(time.Second)
	return fmt.Sprintf("%s%d.%09ds", sign, seconds, nanos)
}
