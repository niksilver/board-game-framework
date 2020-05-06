// Copyright 2020 Nik Silver
//
// Licensed under the GPL v3.0. See file LICENCE.txt for details.

package main

import (
	"fmt"
	"time"

	"github.com/gorilla/websocket"
)

// Hub collects all related clients
type Hub struct {
	//cMux    sync.RWMutex // For reading and writing clients
	clients map[*Client]bool
	// Messages from clients that need to be bounced out.
	Pending chan *Message
	// For the superhub to say there will be no more joiners
	Detached chan bool
	// For the hub to note to itself it's acknowledged the detachement
	detachedAck bool
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
		// Channel size 1 so the superhub doesn't block
		Detached: make(chan bool, 1),
		// For the hub to note to itself it's acknowledged the detachement
		detachedAck: false,
	}
}

// Start starts goroutines running that process the messages.
func (h *Hub) Start() {
	tLog.Debug("hub.Start, adding for receiveInt")
	WG.Add(1)
	go h.receiveInt()
}

// receiveInt is a goroutine that listens for pending messages, and sends
// them out to the relevant clients.
func (h *Hub) receiveInt() {
	defer tLog.Debug("hub.receiveInt, goroutine done")
	defer WG.Done()
	tLog.Debug("hub.receiveInt, entering")

	for !h.detachedAck {
		tLog.Debug("hub.receiveInt, selecting")

		select {
		case <-h.Detached:
			tLog.Debug("hub.receiveInt, received detached flag")
			h.detachedAck = true

		case msg := <-h.Pending:
			tLog.Debug("hub.receiveInt, received pending message")

			switch {
			case !h.clients[msg.From]:
				// New joiner
				c := msg.From

				// Send welcome message to joiner
				tLog.Debug("hub.receiveInt, sending welcome message",
					"fromcid", c.ID)
				c.Pending <- &Message{
					From:  c,
					MType: websocket.BinaryMessage,
					Env: &Envelope{
						To:     []string{c.ID},
						From:   h.allIDs(),
						Time:   time.Now().Unix(),
						Intent: "Welcome",
					},
				}

				// Send joiner message to other clients
				msg := &Message{
					From:  c,
					MType: websocket.BinaryMessage,
					Env: &Envelope{
						From:   []string{c.ID},
						To:     h.allIDs(),
						Time:   time.Now().Unix(),
						Intent: "Joiner",
					},
				}

				tLog.Debug("hub.receiveInt, sending joiner messages",
					"fromcid", c.ID)
				for cl, _ := range h.clients {
					tLog.Debug("hub.receiveInt, sending msg",
						"fromcid", c.ID, "tocid", cl.ID)
					cl.Pending <- msg
				}
				tLog.Debug("hub.receiveInt, sent joiner messages",
					"fromcid", c.ID)

				// Add the client to our list
				h.clients[c] = true

			case msg.Env != nil && msg.Env.Intent == "Leaver":
				// We have a leaver
				c := msg.From
				tLog.Debug("hub.receiveInt, got a leaver", "fromcid", c.ID)

				// Tell the client it will receive no more messages and
				// forget about it
				tLog.Debug("hub.receiveInt, closing cl channel", "fromcid", c.ID)
				close(c.Pending)
				delete(h.clients, c)

				// Send a leaver message to all other clients
				msg := &Message{
					From:  c,
					MType: websocket.BinaryMessage,
					Env: &Envelope{
						From:   []string{c.ID},
						To:     h.allIDs(),
						Time:   time.Now().Unix(),
						Intent: "Leaver",
					},
				}
				tLog.Debug("hub.receiveInt, sending leaver messages")
				for cl, _ := range h.clients {
					tLog.Debug("hub.receiveInt, sending leaver msg",
						"fromcid", c.ID, "tocid", cl.ID)
					cl.Pending <- msg
				}
				tLog.Debug("hub.receiveInt, sent leaver messages")

			case msg.Env != nil && msg.Env.Body != nil:
				// We have a peer message
				c := msg.From
				tLog.Debug("hub.receiveInt, got peer msg", "fromcid", c.ID)

				toCls := h.exclude(c)
				msg.Env.From = []string{c.ID}
				msg.Env.To = ids(toCls)
				msg.Env.Time = time.Now().Unix()
				msg.Env.Intent = "Peer"

				tLog.Debug("hub.receiveInt, sending peer messages")
				for _, cl := range toCls {
					tLog.Debug("hub.receiveInt, sending peer msg",
						"fromcid", c.ID, "tocid", cl.ID)
					cl.Pending <- msg
				}
				tLog.Debug("hub.receiveInt, sent peer messages")

			default:
				// Should never get here
				panic(fmt.Sprintf("Got inexplicable msg: %#v", msg))
			}
		}

	}
}

// exclude finds all clients which aren't the given one.
// Matching is done on pointers.
func (h *Hub) exclude(cx *Client) []*Client {
	tLog.Debug("hub.exclude, entering")
	cOut := make([]*Client, 0)
	for c, _ := range h.clients {
		if c != cx {
			cOut = append(cOut, c)
		}
	}
	tLog.Debug("hub.exclude, exiting")
	return cOut
}

// allIDs returns all the IDs known to the hub
func (h *Hub) allIDs() []string {
	out := make([]string, 0)
	for c, _ := range h.clients {
		out = append(out, c.ID)
	}
	return out
}

// ids returns just the IDs of the clients
func ids(cs []*Client) []string {
	out := make([]string, len(cs))
	for i, c := range cs {
		out[i] = c.ID
	}
	return out
}
