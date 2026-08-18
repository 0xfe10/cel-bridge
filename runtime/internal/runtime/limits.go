package runtime

import (
	"encoding/json"
	"fmt"
	"strings"
)

type Limits struct {
	MaxSourceBytes        int
	MaxEnvironmentBytes   int
	MaxVariablesBytes     int
	MaxTypeDepth          int
	MaxValueDepth         int
	MaxCost               uint64
	MaxIssues             int
	MaxOutputBytes        int
	MaxCompiledPrograms   int
	MaxCachedEnvironments int
	MaxBatchExpressions   int
	MaxBatchSourceBytes   int
	MaxPreparedPrograms   int
}

const (
	ProfileDefault = "default"
	ProfileSafe    = "safe"
	ProfileTrusted = "trusted"
)

var DefaultLimits = Limits{
	MaxSourceBytes:        64 * 1024,
	MaxEnvironmentBytes:   64 * 1024,
	MaxVariablesBytes:     1024 * 1024,
	MaxTypeDepth:          16,
	MaxValueDepth:         32,
	MaxCost:               100_000,
	MaxIssues:             32,
	MaxOutputBytes:        1024 * 1024,
	MaxCompiledPrograms:   128,
	MaxCachedEnvironments: 32,
	MaxBatchExpressions:   256,
	MaxBatchSourceBytes:   1024 * 1024,
	MaxPreparedPrograms:   256,
}

var SafeLimits = Limits{
	MaxSourceBytes:        8 * 1024,
	MaxEnvironmentBytes:   16 * 1024,
	MaxVariablesBytes:     64 * 1024,
	MaxTypeDepth:          8,
	MaxValueDepth:         16,
	MaxCost:               10_000,
	MaxIssues:             16,
	MaxOutputBytes:        256 * 1024,
	MaxCompiledPrograms:   32,
	MaxCachedEnvironments: 8,
	MaxBatchExpressions:   32,
	MaxBatchSourceBytes:   64 * 1024,
	MaxPreparedPrograms:   32,
}

var TrustedLimits = Limits{
	MaxSourceBytes:        256 * 1024,
	MaxEnvironmentBytes:   256 * 1024,
	MaxVariablesBytes:     4 * 1024 * 1024,
	MaxTypeDepth:          16,
	MaxValueDepth:         32,
	MaxCost:               1_000_000,
	MaxIssues:             32,
	MaxOutputBytes:        4 * 1024 * 1024,
	MaxCompiledPrograms:   512,
	MaxCachedEnvironments: 64,
	MaxBatchExpressions:   256,
	MaxBatchSourceBytes:   4 * 1024 * 1024,
	MaxPreparedPrograms:   1024,
}

func LimitsForProfile(name string) (Limits, error) {
	switch name {
	case "", ProfileDefault:
		return DefaultLimits, nil
	case ProfileSafe:
		return SafeLimits, nil
	case ProfileTrusted:
		return TrustedLimits, nil
	default:
		return Limits{}, fmt.Errorf("unknown profile %q", name)
	}
}

func ParseCreateOptions(raw string) (string, Limits, error) {
	profile := ProfileDefault
	trimmed := strings.TrimSpace(raw)
	if trimmed != "" {
		decoder := json.NewDecoder(strings.NewReader(trimmed))
		decoder.DisallowUnknownFields()
		var parsed struct {
			Profile string `json:"profile"`
		}
		if err := decoder.Decode(&parsed); err != nil {
			return "", Limits{}, fmt.Errorf("invalid runtime options: %w", err)
		}
		if decoder.More() {
			return "", Limits{}, fmt.Errorf("runtime options JSON contains trailing data")
		}
		if parsed.Profile != "" {
			profile = parsed.Profile
		}
	}
	limits, err := LimitsForProfile(profile)
	if err != nil {
		return "", Limits{}, err
	}
	return profile, limits, nil
}

func (l Limits) Public() map[string]int {
	return map[string]int{
		"maxSourceBytes":        l.MaxSourceBytes,
		"maxEnvironmentBytes":   l.MaxEnvironmentBytes,
		"maxVariablesBytes":     l.MaxVariablesBytes,
		"maxTypeDepth":          l.MaxTypeDepth,
		"maxValueDepth":         l.MaxValueDepth,
		"maxCost":               int(l.MaxCost),
		"maxOutputBytes":        l.MaxOutputBytes,
		"maxCompiledPrograms":   l.MaxCompiledPrograms,
		"maxCachedEnvironments": l.MaxCachedEnvironments,
		"maxBatchSize":          l.MaxBatchExpressions,
		"maxPreparedPrograms":   l.MaxPreparedPrograms,
	}
}
