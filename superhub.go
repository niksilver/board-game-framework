// Copyright 2020 Nik Silver
//
// Licensed under the GPL v3.0. See file LICENCE.txt for details.

package main

import (
	"sync"
)

type superhub struct {
	hubs  map[string]*Hub // From game name (path) to hub
	names map[*Hub]string // From hub pointer to game name
	mux   sync.RWMutex    // To ensure concurrency-safety
}

// newSuperhub creates an empty superhub, which will hold many hubs.
func newSuperhub() *superhub {
	return &superhub{
		hubs:  make(map[string]*Hub), // From game name (path) to hub
		names: make(map[*Hub]string), // From hub pointer to game name
		//mux:   sync.RWMutex{},        // To ensure concurrency-safety
	}
}

// hub gets the hub for the given game name. If necessary it will create
// a new hub and start it processing.
func (sh *superhub) hub(name string) *Hub {
	sh.mux.Lock()
	defer sh.mux.Unlock()

	if h, okay := sh.hubs[name]; okay {
		return h
	}

	h := NewHub()
	sh.hubs[name] = h
	sh.names[h] = name
	h.Start()

	return h
}

// hasHub check if the superhub has registered a hub for the named game.
func (sh *superhub) hasHub(name string) bool {
	sh.mux.RLock()
	defer sh.mux.RUnlock()

	_, okay := sh.hubs[name]
	return okay
}

// remove removes the given hub from the superhub
func (sh *superhub) remove(h *Hub) {
	sh.mux.RLock()
	defer sh.mux.Unlock()
	delete(sh.hubs, sh.names[h])
	delete(sh.names, h)
}
