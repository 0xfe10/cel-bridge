package runtime

import (
	"sync"

	"github.com/google/cel-go/cel"

	"github.com/0xfe10/cel-bridge/runtime/internal/protocol"
)

type compileCall struct {
	done    chan struct{}
	program cel.Program
	fail    protocol.Response
	ok      bool
}

type compileFlight struct {
	mu    sync.Mutex
	calls map[programKey]*compileCall
}

func newCompileFlight() *compileFlight {
	return &compileFlight{calls: make(map[programKey]*compileCall)}
}

func (f *compileFlight) Do(
	key programKey,
	compile func() (cel.Program, protocol.Response, bool),
) (cel.Program, protocol.Response, bool) {
	f.mu.Lock()
	if call, ok := f.calls[key]; ok {
		f.mu.Unlock()
		<-call.done
		return call.program, call.fail, call.ok
	}
	call := &compileCall{done: make(chan struct{})}
	f.calls[key] = call
	f.mu.Unlock()

	call.program, call.fail, call.ok = compile()
	close(call.done)

	f.mu.Lock()
	delete(f.calls, key)
	f.mu.Unlock()
	return call.program, call.fail, call.ok
}
