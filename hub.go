// Copyright 2020 Nik Silver
//
// Licensed under the GPL v3.0. See file LICENCE.txt for details.

package main

import (
	"sync"
	"time"
)

// Hub collects all related clients
type Hub struct {
	cMux    sync.RWMutex // For reading and writing clients
	clients map[*Client]bool
	// Messages from clients that need to be bounced out.
	Pending chan *Message
	// The client will send true when it wants the hub to stop using it
	stopReq chan *Client
}

// Message is something that the Hub needs to bounce out to clients
// other than the sender.
type Message struct {
	From  *Client
	MType int
	Env   *Envelope
}

// Envelope is the structure for messages sent to clients. Other than msg,
// all fields will be filled in by the hub. This struct has to be exported
// to be processed by json marshalling.
type Envelope struct {
	From   string   // Client id this is from
	To     []string // Ids of all clients this is going to
	Time   int64    // Server time when sent, in seconds since the epoch
	Intent string   // What the message is intended to convey
	Body   []byte   // Original raw message from the sending client
}

// NewHub creates a new, empty Hub.
func NewHub() *Hub {
	return &Hub{
		clients: make(map[*Client]bool),
		Pending: make(chan *Message),
		stopReq: make(chan *Client),
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

// HasClient checks if the client is known to the hub.
func (h *Hub) HasClient(id string) bool {
	cs := h.Clients()
	for _, c := range cs {
		if c.ID == id {
			return true
		}
	}
	return false
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
	go h.receiveInt()
}

// receiveInt is a goroutine that listens for pending messages, and sends
// them out to the relevant clients.
func (h *Hub) receiveInt() {
	for {
		select {
		case c := <-h.stopReq:
			// Defend against getting a stop request twice for the same
			// client. We're not allowed to close a channel twice.
			if h.clients[c] {
				h.Remove(c)
				close(c.Pending)
			}
			if len(h.Clients()) == 0 {
			}
		case msg := <-h.Pending:
			toCls, toIDs := exclude(h.Clients(), msg.From.ID)
			msg.Env.From = msg.From.ID
			msg.Env.To = toIDs
			msg.Env.Time = time.Now().Unix()
			msg.Env.Intent = "Peer"
			for _, c := range toCls {
				c.Pending <- msg
			}
		}
	}
}

// exclude finds all clients from a list which don't match the given one.
// It returns a list of clients and the equivalent list of IDs.
// Matching is done on IDs.
func exclude(cs []*Client, id string) ([]*Client, []string) {
	cPtr, cStr := make([]*Client, 0), make([]string, 0)
	for _, c := range cs {
		if c.ID != id {
			cPtr = append(cPtr, c)
			cStr = append(cStr, c.ID)
		}
	}
	return cPtr, cStr
}
