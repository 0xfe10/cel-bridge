package runtime

import (
	"encoding/json"
	"fmt"
	"testing"
)

const (
	simpleSource = `age >= 18`
)

const complexEnvironment = `{
  "schemaVersion": 1,
  "variables": {
    "age": {"type": "int"},
    "user": {"type": "map", "key": {"type": "string"}, "value": {"type": "dyn"}},
    "items": {"type": "list", "element": {"type": "map", "key": {"type": "string"}, "value": {"type": "dyn"}}},
    "flag": {"type": "bool"},
    "limit": {"type": "int"},
    "region": {"type": "string"},
    "score": {"type": "double"},
    "created": {"type": "timestamp"},
    "ttl": {"type": "duration"},
    "notes": {"type": "string"}
  }
}`

const complexVariables = `{
  "age": 34,
  "user": {
    "country": "CN",
    "name": "Ada",
    "tier": "gold",
    "score": 90,
    "tags": ["a", "b"]
  },
  "items": [{"qty": 2}, {"qty": 0}],
  "flag": true,
  "limit": 10,
  "region": "apac",
  "score": 1.5,
  "created": {"$cel_bridge": true, "kind": "timestamp", "value": "2024-06-01T00:00:00Z"},
  "ttl": {"$cel_bridge": true, "kind": "duration", "value": "1h"},
  "notes": "ok"
}`

const complexCEL = `age >= 18 &&
user["country"] in ["CN", "SG", "JP"] &&
size(items) > 0 &&
items.exists(item, item["qty"] > 0) &&
user["name"].startsWith("A") &&
(user["tier"] == "gold" || user["score"] >= 80) &&
size(user["tags"]) < 16 &&
flag &&
limit > 0 &&
region.startsWith("ap") &&
score > 0.0 &&
notes.startsWith("o") &&
ttl > duration("1s")`

func BenchmarkEvaluateColdSimple(b *testing.B) {
	benchmarkCold(b, testEnvironment, simpleSource, `{"age":20}`)
}

func BenchmarkEvaluateColdComplex(b *testing.B) {
	benchmarkCold(b, complexEnvironment, complexCEL, complexVariables)
}

func BenchmarkEvaluateWarmSimple(b *testing.B) {
	benchmarkWarm(b, testEnvironment, simpleSource, `{"age":20}`)
}

func BenchmarkEvaluateWarmComplex(b *testing.B) {
	benchmarkWarm(b, complexEnvironment, complexCEL, complexVariables)
}

func BenchmarkEvaluate30Expressions(b *testing.B) {
	runtime := New(DefaultLimits)
	sources := thirtySources()
	encoded, err := json.Marshal(sources)
	if err != nil {
		b.Fatal(err)
	}
	runtime.EvaluateMany(testEnvironment, string(encoded), `{"age":20}`)
	b.ReportMetric(float64(runtime.compiledCount()), "compiles")
	b.ReportMetric(float64(runtime.programs.Hits()), "cache_hits")
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		response := runtime.EvaluateMany(testEnvironment, string(encoded), `{"age":21}`)
		if !response.OK {
			b.Fatalf("batch failed: %#v", response)
		}
	}
	b.StopTimer()
	b.ReportMetric(float64(runtime.compiledCount()), "compiles_after")
}

func BenchmarkEvaluateSameProgramChangingVariables(b *testing.B) {
	runtime := New(DefaultLimits)
	runtime.Evaluate(testEnvironment, simpleSource, `{"age":20}`)
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		response := runtime.Evaluate(testEnvironment, simpleSource, fmt.Sprintf(`{"age":%d}`, i%50))
		if !response.OK {
			b.Fatalf("evaluate failed: %#v", response)
		}
	}
	b.StopTimer()
	b.ReportMetric(float64(runtime.compiledCount()), "compiles")
	b.ReportMetric(float64(runtime.programs.Hits()), "cache_hits")
}

func BenchmarkEvaluateParallel(b *testing.B) {
	for _, parallelism := range []int{1, 4, 16, 32} {
		b.Run(fmt.Sprintf("P%d", parallelism), func(b *testing.B) {
			runtime := New(DefaultLimits)
			runtime.Evaluate(testEnvironment, simpleSource, `{"age":20}`)
			b.SetParallelism(parallelism)
			b.ResetTimer()
			b.RunParallel(func(pb *testing.PB) {
				age := 20
				for pb.Next() {
					response := runtime.Evaluate(testEnvironment, simpleSource, fmt.Sprintf(`{"age":%d}`, age))
					if !response.OK {
						b.Errorf("evaluate failed: %#v", response)
						return
					}
					age++
				}
			})
			b.ReportMetric(float64(runtime.compiledCount()), "compiles")
			b.ReportMetric(float64(runtime.programs.Hits()), "cache_hits")
		})
	}
}

func benchmarkCold(b *testing.B, environmentJSON, source, variablesJSON string) {
	b.Helper()
	limits := DefaultLimits
	limits.MaxCompiledPrograms = 0
	limits.MaxCachedEnvironments = 0
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		runtime := New(limits)
		response := runtime.Evaluate(environmentJSON, source, variablesJSON)
		if !response.OK {
			b.Fatalf("evaluate failed: %#v", response)
		}
	}
}

func benchmarkWarm(b *testing.B, environmentJSON, source, variablesJSON string) {
	b.Helper()
	runtime := New(DefaultLimits)
	warm := runtime.Evaluate(environmentJSON, source, variablesJSON)
	if !warm.OK {
		b.Fatalf("prime failed: %#v", warm)
	}
	b.ReportAllocs()
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		response := runtime.Evaluate(environmentJSON, source, variablesJSON)
		if !response.OK {
			b.Fatalf("evaluate failed: %#v", response)
		}
	}
	b.StopTimer()
	b.ReportMetric(float64(runtime.compiledCount()), "compiles")
	b.ReportMetric(float64(runtime.programs.Hits()), "cache_hits")
}

func thirtySources() []string {
	sources := make([]string, 30)
	for i := range sources {
		sources[i] = fmt.Sprintf("age >= %d", i)
	}
	return sources
}
