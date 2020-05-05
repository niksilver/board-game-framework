// Copyright 2020 Nik Silver
//
// Licensed under the GPL v3.0. See file LICENCE.txt for details.

package main

import (
	"fmt"
	"sync"
)

const MaxClients = 50

// Superhub gives a hub to a client. The client needs to
// release the hub when it's done with it.
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

// Hub gets the hub for the given game name. If necessary a new hub
// will be created and start processing messages.
// Will return an error if there are too many clients in the game.
func (sh *Superhub) Hub(name string) (*Hub, error) {
	sh.mux.Lock()
	defer sh.mux.Unlock()
	tLog.Debug("superhub.Hub, giving hub", "name", name)

	if h, okay := sh.hubs[name]; okay {
		if sh.counts[h] >= MaxClients {
			return nil, fmt.Errorf("Maximum number of clients in game")
		}
		sh.counts[h]++
		tLog.Debug("superhub.Hub, existing hub",
			"name", name, "count", sh.counts[h])
		return h, nil
	}

	tLog.Debug("superhub.Hub, new hub", "name", name)
	h := NewHub()
	sh.hubs[name] = h
	sh.counts[h] = 1
	sh.names[h] = name
	tLog.Debug("superhub.Hub, starting hub", "name", name)
	h.Start()
	tLog.Debug("superhub.Hub, exiting", "name", name)

	return h, nil
}

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
		tLog.Debug("superhub.Release, sending detached flag", "name", sh.names[h])
		h.Detached <- true
		tLog.Debug("superhub.Release, sent detached flag", "name", sh.names[h])
	}
	tLog.Debug("superhub.Release, exiting",
		"name", sh.names[h], "count", sh.counts[h])
}

// Count returns the number of hubs in the superhub
func (sh *Superhub) Count() int {
	sh.mux.RLock()
	defer sh.mux.RUnlock()

	for _, name := range sh.names {
		tLog.Debug("superhub.count, counting", "name", name)
	}
	return len(sh.names)
}
