// Copyright 2020 Nik Silver
//
// Licensed under the GPL v3.0. See file LICENCE.txt for details.

package main

import (
	"sync"

	"github.com/niksilver/board-game-framework/log"
)

// Hub collects all related clients
type Hub struct {
	cMux    sync.RWMutex // For reading and writing clients
	clients map[*Client]bool
	// Messages that need to be bounced out
	Pending chan *Message
}

// Message is something that the Hub needs to bounce out to clients
// other than the sender.
type Message struct {
	From  *Client
	MType int
	Msg   []byte
}

// NewHub creates a new, empty Hub.
func NewHub() *Hub {
	return &Hub{
		clients: make(map[*Client]bool),
	}
}

// Add adds a new Client into the Hub.
func (h *Hub) Add(c *Client) {
	h.cMux.Lock()
	defer h.cMux.Unlock()

	h.clients[c] = true
}

// Remove removed a client from the hub.
func (h *Hub) Remove(c *Client) {
	h.cMux.Lock()
	defer h.cMux.Unlock()

	delete(h.clients, c)
}

// Clients returns a new slice with all the Hub's Clients.
func (h *Hub) Clients() []*Client {
	h.cMux.RLock()
	defer h.cMux.RUnlock()

	cs := make([]*Client, 0, len(h.clients))
	for c := range h.clients {
		cs = append(cs, c)
	}

	return cs
}

// Start starts goroutines running that process the messages.
func (h *Hub) Start() {
	log.Log.Debug("In Hub.Start()")
	go h.receiveInt()
}

// receiveInt is a goroutine that listens for pending messages, and sends
// them out to the relevant clients.
func (h *Hub) receiveInt() {
	log.Log.Debug("Hub.receiveInt()")
	for {
		msg := <-h.Pending
		log.Log.Debug(
			"Hub.receiveInt() got message",
			"from ID", msg.From.ID,
			"msg", msg.Msg,
		)
		for _, c := range h.Clients() {
			if c.ID != msg.From.ID {
				c.Pending <- msg
			}
		}
	}
}
