package runtime

import "testing"

func TestParseCreateOptionsAppliesResourceOverrides(t *testing.T) {
	profile, limits, err := ParseCreateOptions(`{"profile":"safe","limits":{"maxCompiledPrograms":256,"maxBatchExpressions":64,"maxPreparedPrograms":128}}`)
	if err != nil {
		t.Fatal(err)
	}
	if profile != ProfileSafe {
		t.Fatalf("profile=%q", profile)
	}
	if limits.MaxCompiledPrograms != 256 || limits.MaxBatchExpressions != 64 || limits.MaxPreparedPrograms != 128 {
		t.Fatalf("unexpected limits: %#v", limits)
	}
	if limits.MaxCost != SafeLimits.MaxCost || limits.MaxVariablesBytes != SafeLimits.MaxVariablesBytes {
		t.Fatalf("safety limits changed: %#v", limits)
	}
}

func TestParseCreateOptionsRejectsNonPositiveResourceOverrides(t *testing.T) {
	for _, field := range []string{"maxCompiledPrograms", "maxBatchExpressions", "maxPreparedPrograms"} {
		_, _, err := ParseCreateOptions(`{"limits":{"` + field + `":0}}`)
		if err == nil {
			t.Fatalf("expected %s to be rejected", field)
		}
	}
}
