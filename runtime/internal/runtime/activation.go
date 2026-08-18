package runtime

import "github.com/google/cel-go/interpreter"

type trackingActivation struct {
	vars    map[string]any
	missing []string
}

func (a *trackingActivation) ResolveName(name string) (any, bool) {
	value, ok := a.vars[name]
	if !ok {
		a.missing = append(a.missing, name)
		return nil, false
	}
	return value, true
}

func (a *trackingActivation) Parent() interpreter.Activation {
	return nil
}
