// Copyright 2020 Nik Silver
//
// Licensed under the GPL v3.0. See file LICENCE.txt for details.

package main

import (
	"sync"
)

type Superhub struct {
	hubs   map[string]*Hub // From game name (path) to hub
	counts map[*Hub]int    // Count of clients using each hub
	names  map[*Hub]string // From hub pointer to game name
	mux    sync.RWMutex    // To ensure concurrency-safety
}

// newSuperhub creates an empty superhub, which will hold many hubs.
func NewSuperhub() *Superhub {
	return &Superhub{
		hubs:   make(map[string]*Hub), // From game name (path) to hub
		counts: make(map[*Hub]int),    // Count of clients using each hub
		names:  make(map[*Hub]string), // From hub pointer to game name
		mux:    sync.RWMutex{},        // To ensure concurrency-safety
	}
}

// hub gets the hub for the given game name. If necessary it will create
// a new hub and start it processing.
func (sh *Superhub) Hub(name string) *Hub {
	sh.mux.Lock()
	defer sh.mux.Unlock()
	tLog.Debug("superhub.Hub, giving hub", "name", name)

	if h, okay := sh.hubs[name]; okay {
		sh.counts[h]++
		tLog.Debug("superhub.Hub, existing hub",
			"name", name, "count", sh.counts[h])
		return h
	}

	tLog.Debug("superhub.Hub, new hub", "name", name)
	h := NewHub()
	sh.hubs[name] = h
	sh.counts[h] = 0
	sh.names[h] = name
	tLog.Debug("superhub.Hub, starting hub", "name", name)
	h.Start()
	tLog.Debug("superhub.Hub, exiting", "name", name)

	return h
}

/*// hasHub check if the superhub has registered a hub for the named game.
func (sh *Superhub) hasHub(name string) bool {
	sh.mux.RLock()
	defer sh.mux.RUnlock()

	_, okay := sh.hubs[name]
	return okay
}*/

// Release allows a client to say it is no longer using the given hub.
// If that means no clients are using the hub then the hub will be told
// it is detached.
func (sh *Superhub) Release(h *Hub) {
	sh.mux.Lock()
	defer sh.mux.Unlock()
	tLog.Debug("superhub.Release, releasing hub", "name", sh.names[h])

	sh.counts[h]--
	if sh.counts[h] == 0 {
		tLog.Debug("superhub.Release, deleting hub", "name", sh.names[h])
		delete(sh.hubs, sh.names[h])
		delete(sh.names, h)
		h.Detached = true
	}
	tLog.Debug("superhub.Release, exiting",
		"name", sh.names[h], "count", sh.counts[h])
}

// count returns the number of hubs in the superhub
func (sh *Superhub) Count() int {
	sh.mux.RLock()
	defer sh.mux.RUnlock()

	for _, name := range sh.names {
		tLog.Debug("superhub.count, counting", "name", name)
	}
	return len(sh.names)
}
