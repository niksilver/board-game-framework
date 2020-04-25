// Copyright 2020 Nik Silver
//
// Licensed under the GPL v3.0. See file LICENCE.txt for details.

package main

import (
	"sync"
)

// Hub collects all related clients
type Hub struct {
	cMux    sync.RWMutex // For reading and writing clients
	clients map[*Client]bool
	// Messages that need to be bounced out.
	Pending chan *Message
	// The client will send true when it wants the hub to stop using it
	stopReq chan *Client
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
	tLog.Debug("hub.Remove(), entering", "clientID", c.ID)
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
	go h.receiveInt()
}

// receiveInt is a goroutine that listens for pending messages, and sends
// them out to the relevant clients.
func (h *Hub) receiveInt() {
	for {
		tLog.Debug(
			"hub.receiveInt() waiting for message or stop request",
		)
		select {
		case c := <-h.stopReq:
			// Defend against getting a stop request twice for the same
			// client. We're not allowed to close a channel twice.
			if h.clients[c] {
				h.Remove(c)
				close(c.Pending)
			}
			if len(h.Clients()) == 0 {
				tLog.Info(
					"hub.receiveInt(), no more clients. What to do?",
				)
			}
		case msg := <-h.Pending:
			tLog.Debug(
				"hub.receiveInt() got message",
				"fromID", msg.From.ID,
				"msg", msg.Msg,
			)
			for _, c := range h.Clients() {
				if c.ID != msg.From.ID {
					tLog.Debug(
						"hub.receiveInt() sending msg to client",
						"clientID", c.ID,
						"msg", msg.Msg,
					)
					c.Pending <- msg
					tLog.Debug(
						"hub.receiveInt() sent    msg to client",
						"clientID", c.ID,
					)
				}
			}
			tLog.Debug(
				"hub.receiveInt() sent all messages",
				"fromID", msg.From.ID,
				"msg", msg.Msg,
			)
		}
	}
}
