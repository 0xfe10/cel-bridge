package runtime

type Limits struct {
	MaxSourceBytes      int
	MaxEnvironmentBytes int
	MaxVariablesBytes   int
	MaxTypeDepth        int
	MaxValueDepth       int
	MaxCost             uint64
	MaxIssues           int
	MaxOutputBytes      int
}

var DefaultLimits = Limits{
	MaxSourceBytes:      64 * 1024,
	MaxEnvironmentBytes: 64 * 1024,
	MaxVariablesBytes:   1024 * 1024,
	MaxTypeDepth:        16,
	MaxValueDepth:       32,
	MaxCost:             100_000,
	MaxIssues:           32,
	MaxOutputBytes:      1024 * 1024,
}
