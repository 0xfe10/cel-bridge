package runtime

import (
	"container/list"
	"crypto/sha256"
	"sync"

	"github.com/google/cel-go/cel"
)

type environmentKey [32]byte

type cachedEnvironment struct {
	key environmentKey
	env *cel.Env
}

type environmentCache struct {
	mu       sync.Mutex
	capacity int
	entries  map[environmentKey]*list.Element
	order    *list.List
}

func newEnvironmentCache(capacity int) *environmentCache {
	if capacity < 0 {
		capacity = 0
	}
	return &environmentCache{
		capacity: capacity,
		entries:  make(map[environmentKey]*list.Element),
		order:    list.New(),
	}
}

func makeEnvironmentKey(environmentJSON string) environmentKey {
	return sha256.Sum256([]byte(environmentJSON))
}

func (c *environmentCache) Get(key environmentKey) (*cel.Env, bool) {
	if c == nil || c.capacity == 0 {
		return nil, false
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	element, ok := c.entries[key]
	if !ok {
		return nil, false
	}
	c.order.MoveToFront(element)
	return element.Value.(*cachedEnvironment).env, true
}

func (c *environmentCache) Put(key environmentKey, env *cel.Env) {
	if c == nil || c.capacity == 0 || env == nil {
		return
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	if element, ok := c.entries[key]; ok {
		element.Value = &cachedEnvironment{key: key, env: env}
		c.order.MoveToFront(element)
		return
	}
	element := c.order.PushFront(&cachedEnvironment{key: key, env: env})
	c.entries[key] = element
	for c.order.Len() > c.capacity {
		tail := c.order.Back()
		if tail == nil {
			return
		}
		evicted := c.order.Remove(tail).(*cachedEnvironment)
		delete(c.entries, evicted.key)
	}
}

func (c *environmentCache) Len() int {
	if c == nil {
		return 0
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	return c.order.Len()
}
