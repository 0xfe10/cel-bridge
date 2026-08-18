package runtime

import (
	"container/list"
	"crypto/sha256"
	"encoding/binary"
	"hash"
	"sync"
	"sync/atomic"

	"github.com/google/cel-go/cel"
)

type programKey [32]byte

type compiledProgram struct {
	key     programKey
	program cel.Program
}

type programCache struct {
	mu       sync.Mutex
	capacity int
	entries  map[programKey]*list.Element
	order    *list.List
	hits     atomic.Int64
	misses   atomic.Int64
}

func newProgramCache(capacity int) *programCache {
	if capacity < 0 {
		capacity = 0
	}
	return &programCache{
		capacity: capacity,
		entries:  make(map[programKey]*list.Element),
		order:    list.New(),
	}
}

func makeProgramKey(environmentJSON, source string) programKey {
	digest := sha256.New()
	digest.Write([]byte{1})
	writeLengthAndString(digest, environmentJSON)
	writeLengthAndString(digest, source)
	var key programKey
	copy(key[:], digest.Sum(nil))
	return key
}

func writeLengthAndString(digest hash.Hash, value string) {
	var length [8]byte
	binary.BigEndian.PutUint64(length[:], uint64(len(value)))
	digest.Write(length[:])
	digest.Write([]byte(value))
}

func (c *programCache) Get(key programKey) (cel.Program, bool) {
	if c == nil || c.capacity == 0 {
		if c != nil {
			c.misses.Add(1)
		}
		return nil, false
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	element, ok := c.entries[key]
	if !ok {
		c.misses.Add(1)
		return nil, false
	}
	c.order.MoveToFront(element)
	c.hits.Add(1)
	return element.Value.(*compiledProgram).program, true
}

func (c *programCache) Put(key programKey, program cel.Program) {
	if c == nil || c.capacity == 0 || program == nil {
		return
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	if element, ok := c.entries[key]; ok {
		element.Value = &compiledProgram{key: key, program: program}
		c.order.MoveToFront(element)
		return
	}
	element := c.order.PushFront(&compiledProgram{key: key, program: program})
	c.entries[key] = element
	for c.order.Len() > c.capacity {
		tail := c.order.Back()
		if tail == nil {
			return
		}
		evicted := c.order.Remove(tail).(*compiledProgram)
		delete(c.entries, evicted.key)
	}
}

func (c *programCache) Len() int {
	if c == nil {
		return 0
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	return c.order.Len()
}

func (c *programCache) Hits() int64 {
	if c == nil {
		return 0
	}
	return c.hits.Load()
}

func (c *programCache) Misses() int64 {
	if c == nil {
		return 0
	}
	return c.misses.Load()
}
