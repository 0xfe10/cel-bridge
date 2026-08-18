package runtime

import (
	"encoding/json"
	"fmt"
	"sync"
	"testing"

	"github.com/0xfe10/cel-bridge/runtime/internal/protocol"
	"github.com/google/cel-go/cel"
)

func TestProgramCacheSameInputHits(t *testing.T) {
	runtime := New(DefaultLimits)
	first := runtime.Evaluate(testEnvironment, `age >= 18`, `{"age":20}`)
	if !first.OK {
		t.Fatalf("first evaluate failed: %#v", first)
	}
	if runtime.compiledCount() != 1 {
		t.Fatalf("expected 1 compile, got %d", runtime.compiledCount())
	}
	second := runtime.Evaluate(testEnvironment, `age >= 18`, `{"age":21}`)
	if !second.OK {
		t.Fatalf("second evaluate failed: %#v", second)
	}
	if runtime.compiledCount() != 1 {
		t.Fatalf("warm evaluate compiled again: %d", runtime.compiledCount())
	}
	if runtime.programs.Hits() != 1 || runtime.programCacheLen() != 1 {
		t.Fatalf("hits=%d len=%d", runtime.programs.Hits(), runtime.programCacheLen())
	}
}

func TestProgramCacheDifferentSourceMisses(t *testing.T) {
	runtime := New(DefaultLimits)
	runtime.Evaluate(testEnvironment, `age >= 18`, `{"age":20}`)
	runtime.Evaluate(testEnvironment, `age >= 21`, `{"age":20}`)
	if runtime.compiledCount() != 2 {
		t.Fatalf("expected 2 compiles, got %d", runtime.compiledCount())
	}
}

func TestProgramCacheDifferentEnvironmentMisses(t *testing.T) {
	runtime := New(DefaultLimits)
	other := `{"schemaVersion":1,"variables":{"age":{"type":"int"},"flag":{"type":"bool"}}}`
	runtime.Evaluate(testEnvironment, `age >= 18`, `{"age":20}`)
	runtime.Evaluate(other, `age >= 18`, `{"age":20}`)
	if runtime.compiledCount() != 2 {
		t.Fatalf("expected 2 compiles, got %d", runtime.compiledCount())
	}
}

func TestProgramCacheDoesNotStoreCompileErrors(t *testing.T) {
	runtime := New(DefaultLimits)
	response := runtime.Evaluate(testEnvironment, `missing == 1`, `{"age":20}`)
	if response.OK || response.Error == nil || response.Error.Code != "compile_error" {
		t.Fatalf("unexpected response: %#v", response)
	}
	if runtime.programCacheLen() != 0 || runtime.compiledCount() != 0 {
		t.Fatalf("compile errors must not be cached")
	}
}

func TestProgramCacheKeepsProgramAfterEvaluationError(t *testing.T) {
	runtime := New(DefaultLimits)
	first := runtime.Evaluate(testEnvironment, `age / 0`, `{"age":20}`)
	if first.OK {
		t.Fatalf("expected evaluation error: %#v", first)
	}
	if runtime.compiledCount() != 1 || runtime.programCacheLen() != 1 {
		t.Fatalf("evaluation errors must leave the program cached")
	}
	second := runtime.Evaluate(testEnvironment, `age / 0`, `{"age":4}`)
	if second.OK {
		t.Fatalf("expected second evaluation error: %#v", second)
	}
	if runtime.compiledCount() != 1 {
		t.Fatalf("cached program was recompiled")
	}
}

func TestProgramCacheDisabled(t *testing.T) {
	limits := DefaultLimits
	limits.MaxCompiledPrograms = 0
	runtime := New(limits)
	runtime.Evaluate(testEnvironment, `age >= 18`, `{"age":20}`)
	runtime.Evaluate(testEnvironment, `age >= 18`, `{"age":21}`)
	if runtime.compiledCount() != 2 || runtime.programCacheLen() != 0 {
		t.Fatalf("capacity 0 must disable the cache")
	}
}

func TestProgramCacheCapacityOneEvicts(t *testing.T) {
	limits := DefaultLimits
	limits.MaxCompiledPrograms = 1
	runtime := New(limits)
	runtime.Evaluate(testEnvironment, `age >= 18`, `{"age":20}`)
	runtime.Evaluate(testEnvironment, `age >= 21`, `{"age":20}`)
	if runtime.programCacheLen() != 1 {
		t.Fatalf("capacity 1 cache grew to %d", runtime.programCacheLen())
	}
	before := runtime.compiledCount()
	runtime.Evaluate(testEnvironment, `age >= 18`, `{"age":20}`)
	if runtime.compiledCount() != before+1 {
		t.Fatalf("evicted program was not recompiled")
	}
}

func TestProgramCacheLRUOrder(t *testing.T) {
	limits := DefaultLimits
	limits.MaxCompiledPrograms = 2
	runtime := New(limits)
	runtime.Evaluate(testEnvironment, `age >= 18`, `{"age":20}`)
	runtime.Evaluate(testEnvironment, `age >= 21`, `{"age":20}`)
	runtime.Evaluate(testEnvironment, `age >= 18`, `{"age":22}`)
	runtime.Evaluate(testEnvironment, `age >= 30`, `{"age":20}`)
	if runtime.programCacheLen() != 2 {
		t.Fatalf("capacity 2 cache grew to %d", runtime.programCacheLen())
	}
	before := runtime.compiledCount()
	runtime.Evaluate(testEnvironment, `age >= 18`, `{"age":20}`)
	if runtime.compiledCount() != before {
		t.Fatalf("recent program was evicted")
	}
	runtime.Evaluate(testEnvironment, `age >= 21`, `{"age":20}`)
	if runtime.compiledCount() != before+1 {
		t.Fatalf("least-recent program was not evicted")
	}
}

func TestProgramCacheConcurrentGetPut(t *testing.T) {
	cache := newProgramCache(8)
	env, err := cel.NewEnv(cel.Variable("age", cel.IntType))
	if err != nil {
		t.Fatal(err)
	}
	ast, issues := env.Compile(`age >= 18`)
	if issues.Err() != nil {
		t.Fatal(issues.Err())
	}
	program, err := env.Program(ast)
	if err != nil {
		t.Fatal(err)
	}
	var wait sync.WaitGroup
	for i := 0; i < 32; i++ {
		wait.Add(1)
		go func(i int) {
			defer wait.Done()
			key := makeProgramKey(testEnvironment, fmt.Sprintf("age >= %d", i%4))
			cache.Put(key, program)
			cache.Get(key)
		}(i)
	}
	wait.Wait()
	if cache.Len() > 8 {
		t.Fatalf("cache exceeded capacity: %d", cache.Len())
	}
}

func TestConcurrentEvalSameProgram(t *testing.T) {
	runtime := New(DefaultLimits)
	runtime.Evaluate(testEnvironment, `age >= 18`, `{"age":20}`)
	var wait sync.WaitGroup
	for i := 0; i < 32; i++ {
		wait.Add(1)
		go func(i int) {
			defer wait.Done()
			response := runtime.Evaluate(testEnvironment, `age >= 18`, fmt.Sprintf(`{"age":%d}`, 10+i))
			expected := 10+i >= 18
			if !response.OK {
				t.Errorf("evaluate failed: %#v", response)
				return
			}
			if response.Result.(protocol.Value).Value != expected {
				t.Errorf("unexpected result for age=%d: %#v", 10+i, response.Result)
			}
		}(i)
	}
	wait.Wait()
	if runtime.compiledCount() != 1 {
		t.Fatalf("concurrent eval recompiled: %d", runtime.compiledCount())
	}
}

func TestCostLimitAppliesPerEval(t *testing.T) {
	limits := DefaultLimits
	limits.MaxCost = 0
	runtime := New(limits)
	first := runtime.Evaluate(`{"schemaVersion":1,"variables":{}}`, `1 + 1`, `{}`)
	if first.OK || first.Error == nil || first.Error.Code != "cost_limit_exceeded" {
		t.Fatalf("unexpected first response: %#v", first)
	}
	second := runtime.Evaluate(`{"schemaVersion":1,"variables":{}}`, `1 + 1`, `{}`)
	if second.OK || second.Error == nil || second.Error.Code != "cost_limit_exceeded" {
		t.Fatalf("unexpected second response: %#v", second)
	}
	if runtime.compiledCount() != 1 {
		t.Fatalf("cost-limited eval recompiled: %d", runtime.compiledCount())
	}
}

func TestThirtyExpressionsSecondRoundDoesNotCompile(t *testing.T) {
	runtime := New(DefaultLimits)
	sources := make([]string, 30)
	for i := range sources {
		sources[i] = fmt.Sprintf("age >= %d", i)
	}
	encoded, err := json.Marshal(sources)
	if err != nil {
		t.Fatal(err)
	}
	first := runtime.EvaluateMany(testEnvironment, string(encoded), `{"age":20}`)
	if !first.OK {
		t.Fatalf("first batch failed: %#v", first)
	}
	if runtime.compiledCount() != 30 {
		t.Fatalf("expected 30 first-round compiles, got %d", runtime.compiledCount())
	}
	second := runtime.EvaluateMany(testEnvironment, string(encoded), `{"age":21}`)
	if !second.OK {
		t.Fatalf("second batch failed: %#v", second)
	}
	if runtime.compiledCount() != 30 {
		t.Fatalf("second round compiled: %d", runtime.compiledCount())
	}
	if runtime.programCacheLen() > 128 {
		t.Fatalf("cache exceeded 128: %d", runtime.programCacheLen())
	}
}

func TestEvaluateManyPartialFailurePreservesOrder(t *testing.T) {
	runtime := New(DefaultLimits)
	response := runtime.EvaluateMany(
		testEnvironment,
		`["age >= 18","missing == 1","age >= 21"]`,
		`{"age":20}`,
	)
	items := batchItems(t, response)
	if len(items) != 3 {
		t.Fatalf("expected 3 items, got %#v", response.Result)
	}
	if !items[0].OK || items[1].OK || items[1].Error == nil || items[1].Error.Code != "compile_error" || !items[2].OK {
		t.Fatalf("unexpected batch items: %#v", items)
	}
}

func TestEvaluateManyRejectsTooManyExpressions(t *testing.T) {
	runtime := New(DefaultLimits)
	sources := make([]string, 257)
	for i := range sources {
		sources[i] = "true"
	}
	encoded, err := json.Marshal(sources)
	if err != nil {
		t.Fatal(err)
	}
	response := runtime.EvaluateMany(`{"schemaVersion":1,"variables":{}}`, string(encoded), `{}`)
	if response.OK || response.Error == nil || response.Error.Code != "invalid_request" {
		t.Fatalf("expected invalid_request, got %#v", response)
	}
}

func TestEvaluateManyEmptyBatch(t *testing.T) {
	runtime := New(DefaultLimits)
	response := runtime.EvaluateMany(testEnvironment, `[]`, `{"age":20}`)
	items := batchItems(t, response)
	if !response.OK || len(items) != 0 {
		t.Fatalf("unexpected empty batch: %#v", response)
	}
}

func TestEnvironmentCacheSharedAcrossSources(t *testing.T) {
	runtime := New(DefaultLimits)
	runtime.Evaluate(testEnvironment, `age >= 18`, `{"age":20}`)
	runtime.Evaluate(testEnvironment, `age >= 21`, `{"age":20}`)
	if runtime.environments.Len() != 1 {
		t.Fatalf("expected one cached environment, got %d", runtime.environments.Len())
	}
}

func TestEnvironmentConcurrentCompile(t *testing.T) {
	env, err := cel.NewEnv(cel.Variable("age", cel.IntType))
	if err != nil {
		t.Fatal(err)
	}
	var wait sync.WaitGroup
	for i := 0; i < 32; i++ {
		wait.Add(1)
		go func(i int) {
			defer wait.Done()
			_, issues := env.Compile(fmt.Sprintf("age >= %d", i))
			if issues.Err() != nil {
				t.Errorf("compile failed: %v", issues.Err())
			}
		}(i)
	}
	wait.Wait()
}

func batchItems(t *testing.T, response protocol.Response) []protocol.Response {
	t.Helper()
	if !response.OK {
		t.Fatalf("batch request failed: %#v", response)
	}
	items, ok := response.Result.(*[]protocol.Response)
	if !ok {
		t.Fatalf("unexpected batch result type %T", response.Result)
	}
	return *items
}
