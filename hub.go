// Copyright 2020 Nik Silver
//
// Licensed under the GPL v3.0. See file LICENCE.txt for details.

package main

import (
	"sync"
	"time"

	"github.com/gorilla/websocket"
)

// Hub collects all related clients
type Hub struct {
	cMux    sync.RWMutex // For reading and writing clients
	clients map[*Client]bool
	// Messages from clients that need to be bounced out.
	Pending chan *Message
	// Joiner clients, to trigger joiner messages
	Joiners chan *Client
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
		Joiners: make(chan *Client),
		stopReq: make(chan *Client),
	}
}

// Add adds a new Client into the Hub and triggers a joiner message.
func (h *Hub) Add(c *Client) {
	h.cMux.Lock()
	defer h.cMux.Unlock()

	h.clients[c] = true

	tLog.Debug("Sending joiner message", "id", c.ID)
	if c.Websocket != nil {
		// Only do this if we've got a real client
		h.Joiners <- c
	}
	/*h.Pending <- &Message{
		From: c,
		Env: &Envelope{
			Intent: "Joiner",
		},
	}*/
	tLog.Debug("Sent joiner message", "id", c.ID)
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

// NumClients returns the number of clients in the hub.
func (h *Hub) NumClients() int {
	h.cMux.RLock()
	defer h.cMux.RUnlock()

	return len(h.clients)
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
		case c := <-h.Joiners:
			toCls, toIDs := exclude(h.Clients(), c.ID)
			msg := &Message{
				From:  c,
				MType: websocket.BinaryMessage,
				Env: &Envelope{
					From:   c.ID,
					To:     toIDs,
					Time:   time.Now().Unix(),
					Intent: "Joiner",
				},
			}
			for _, cl := range toCls {
				tLog.Debug("receiveInt: Sending joiner msg", "rcptID", cl.ID)
				cl.Pending <- msg
				tLog.Debug("receiveInt: Sent joiner msg", "rcptID", cl.ID)
			}
		case msg := <-h.Pending:
			switch {
			/*case msg.Env != nil && msg.Env.Intent == "Joiner":
			toCls, toIDs := exclude(h.Clients(), msg.From.ID)
			msg.Env.From = msg.From.ID
			msg.Env.To = toIDs
			msg.Env.Time = time.Now().Unix()
			for _, c := range toCls {
				c.Pending <- msg
			}*/
			default:
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
