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

// Envelope is the structure for messages sent to clients. Other than
// the bare minimum,
// all fields will be filled in by the hub. The fields have to be exported
// to be processed by json marshalling.
type Envelope struct {
	From   []string // Client id this is from
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
	h.clients[c] = true
	h.cMux.Unlock()

	if c.Websocket != nil {
		// Only do this if we've got a real client
		h.Joiners <- c
	}
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
	tLog.Debug("hub.Clients, entering")
	defer tLog.Debug("hub.Clients, exiting")
	h.cMux.RLock()
	tLog.Debug("hub.Clients, got read lock")
	defer h.cMux.RUnlock()

	cs := make([]*Client, 0, len(h.clients))
	for c := range h.clients {
		cs = append(cs, c)
	}

	return cs
}

// ClientIDs returns a new slice with all the Hub's client IDs.
func (h *Hub) ClientIDs() []string {
	h.cMux.RLock()
	defer h.cMux.RUnlock()

	cs := make([]string, 0, len(h.clients))
	for c := range h.clients {
		cs = append(cs, c.ID)
	}

	return cs
}

// Start starts goroutines running that process the messages.
func (h *Hub) Start() {
	tLog.Debug("hub.Start, adding for receiveInt")
	wg.Add(1)
	go h.receiveInt()
}

// receiveInt is a goroutine that listens for pending messages, and sends
// them out to the relevant clients.
func (h *Hub) receiveInt() {
	defer tLog.Debug("hub.receiveInt, goroutine done")
	defer wg.Done()
	for {
		tLog.Debug("hub.receiveInt, selecting")
		select {
		case c := <-h.stopReq:
			tLog.Debug("hub.receiveInt, got stopReq", "cid", c.ID)
			// Defend against getting a stop request twice for the same
			// client. We're not allowed to close a channel twice.
			if h.clients[c] {
				tLog.Debug("hub.receiveInt, removing client", "cid", c.ID)
				h.Remove(c)
				tLog.Debug("hub.receiveInt, closing c.pending", "cid", c.ID)
				close(c.Pending)
				tLog.Debug("hub.receiveInt, closed c.pending", "cid", c.ID)
			}
			if len(h.Clients()) == 0 {
				// No clients left in the hub
				tLog.Debug("hub.receiveInt, removing hub", "cid", c.ID)
				shub.remove(h)
				tLog.Debug("hub.receiveInt, removed, returning", "cid", c.ID)
				return
			}
			tLog.Debug("hub.receiveInt, processed stop request", "cid", c.ID)
		case c := <-h.Joiners:
			tLog.Debug("hub.receiveInt, got joiner", "cid", c.ID)
			toCls := exclude(h.Clients(), c)
			tLog.Debug("hub.receiveInt, got toCls")
			msg := &Message{
				From:  c,
				MType: websocket.BinaryMessage,
				Env: &Envelope{
					From:   []string{c.ID},
					To:     ids(toCls),
					Time:   time.Now().Unix(),
					Intent: "Joiner",
				},
			}
			tLog.Debug("hub.receiveInt, sending msg toCls")
			for _, cl := range toCls {
				tLog.Debug("hub.receiveInt, sending msg", "fromcid", c.ID, "tocid", cl.ID)
				cl.Pending <- msg
			}
			tLog.Debug("hub.receiveInt, sent msg toCls")
		case msg := <-h.Pending:
			tLog.Debug("hub.receiveInt, got pending msg", "cid", msg.From.ID)
			toCls := exclude(h.Clients(), msg.From)
			msg.Env.From = []string{msg.From.ID}
			msg.Env.To = ids(toCls)
			msg.Env.Time = time.Now().Unix()
			msg.Env.Intent = "Peer"
			for _, c := range toCls {
				c.Pending <- msg
			}
		}
	}
}

// exclude finds all clients from a list which don't match the given one.
// Matching is done on pointers.
func exclude(cs []*Client, cx *Client) []*Client {
	tLog.Debug("hub.exclude, entering")
	cOut := make([]*Client, 0)
	for _, c := range cs {
		if c != cx {
			cOut = append(cOut, c)
		}
	}
	tLog.Debug("hub.exclude, exiting")
	return cOut
}

// ids returns just the IDs of the clients
func ids(cs []*Client) []string {
	out := make([]string, len(cs))
	for i, c := range cs {
		out[i] = c.ID
	}
	return out
}
