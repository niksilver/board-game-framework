// Copyright 2020 Nik Silver
//
// Licensed under the GPL v3.0. See file LICENCE.txt for details.

package main

import (
	"fmt"
	"math/rand"
	"net/http"
	"time"

	"github.com/gorilla/websocket"
	"github.com/inconshreveable/log15"
)

// How often we send pings
var pingFreq = 60 * time.Second

// How long we time out waiting for a pong or other data. Must be more
// than pingFreq.
var pongTimeout = (pingFreq * 5) / 4

// How long to allow to write to the websocket.
var writeTimeout = 10 * time.Second

func init() {
	// Let's not generate near-identical client IDs on every restart
	rand.Seed(time.Now().UnixNano())
}

type Client struct {
	ID string
	// Don't close the websocket directly. That's managed internally.
	WS  *websocket.Conn
	Hub *Hub
	// To receive internal message from the hub. The hub will close it
	// once it knows the client wants to stop.
	Pending chan *Message
	log     log15.Logger
	// pinger ticks for pinging
	pinger *time.Ticker
}

var upgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool {
		// If set, the Origin host is in r.Header["Origin"][0])
		// The request host is in r.Host
		// We won't worry about the origin, to help with testing locally
		return true
	},
}

// Upgrade converts an http request to a websocket, ensuring the client ID
// is sent. The ID should be set properly before entering.
func Upgrade(
	w http.ResponseWriter,
	r *http.Request,
	clientID string,
) (*websocket.Conn, error) {
	maxAge := 60 * 60 * 24 * 365 * 100 // 100 years, default expiration
	if clientID == "" {
		// Annul the cookie
		maxAge = -1
	}
	cookie := &http.Cookie{
		Name:   "clientID",
		Value:  clientID,
		Path:   "/",
		MaxAge: maxAge,
	}
	cookieStr := cookie.String()
	header := http.Header(make(map[string][]string))
	header.Add("Set-Cookie", cookieStr)

	return upgrader.Upgrade(w, r, header)
}

// NewClientID generates a random clientID string
func NewClientID() string {
	return fmt.Sprintf(
		"%d.%d",
		time.Now().Unix(),
		rand.Int31(),
	)
}

// clientID returns the value of the clientID cookie, or empty string
// if there's none there.
func ClientID(cookies []*http.Cookie) string {
	for _, cookie := range cookies {
		if cookie.Name == "clientID" {
			return cookie.Value
		}
	}

	return ""
}

// ClientIDOrNew returns the value of the clientID cookie, or a new ID
// if there's none there.
func ClientIDOrNew(cookies []*http.Cookie) string {
	clientID := ClientID(cookies)
	if clientID == "" {
		return NewClientID()
	}
	return clientID
}

// clientID returns the Max-Age value of the clientID cookie,
// or 0 if there's none there
func ClientIDMaxAge(cookies []*http.Cookie) int {
	for _, cookie := range cookies {
		if cookie.Name == "clientID" {
			return cookie.MaxAge
		}
	}

	return 0
}

// Start attaches the client to its hub and starts its goroutines.
func (c *Client) Start() {
	// Create a client-specific logger
	if c.log == nil {
		c.log = Log.New("ID", c.ID)
	}

	// Immediate termination for an excessive message
	c.WS.SetReadLimit(60 * 1024)

	// Set up pinging
	c.pinger = time.NewTicker(pingFreq)
	c.WS.SetReadDeadline(time.Now().Add(pongTimeout))
	c.WS.SetPongHandler(func(string) error {
		c.WS.SetReadDeadline(time.Now().Add(pongTimeout))
		return nil
	})

	// Start sending messages externally
	tLog.Debug("client.start, adding for sendExt", "id", c.ID)
	WG.Add(1)
	go c.sendExt()

	// Start receiving messages from the outside
	tLog.Debug("client.start, adding for receiveExt", "id", c.ID)
	WG.Add(1)
	go c.receiveExt()
}

// receiveExt is a goroutine that acts on external messages coming in.
func (c *Client) receiveExt() {
	defer tLog.Debug("client.receiveExt, goroutine done", "id", c.ID)
	defer WG.Done()

	// First send a joiner message
	c.Hub.Pending <- &Message{
		From: c,
	}

	// Read messages until we can no more
	for {
		tLog.Debug("client.receiveExt, reading", "id", c.ID)
		mType, msg, err := c.WS.ReadMessage()
		if err != nil {
			tLog.Debug(
				"client.receiveExt, read error", "error", err, "id", c.ID,
			)
			break
		}
		// Currently just passes on the message type
		tLog.Debug("client.receiveExt, read is good", "id", c.ID)
		c.Hub.Pending <- &Message{
			From:  c,
			MType: mType,
			Env:   &Envelope{Body: msg},
		}
	}

	// We've done reading, so shut down and send a leaver message
	tLog.Debug("client.receiveExt, closing conn", "id", c.ID)
	c.WS.Close()
	c.Hub.Pending <- &Message{
		From: c,
		Env: &Envelope{
			Intent: "Leaver",
		},
	}
}

// sendExt is a goroutine that sends network messages out. These are
// pings and messages that have come from the hub. It will stop
// if its channel is closed or it can no longer write to the network.
func (c *Client) sendExt() {
	defer tLog.Debug("client.sendExt, goroutine done", "id", c.ID)
	defer WG.Done()

	// Keep receiving internal messages
sendLoop:
	for {
		tLog.Debug("client.sendExt, entering select", "id", c.ID)
		select {
		case m, ok := <-c.Pending:
			tLog.Debug("client.sendExt, got pending", "id", c.ID)
			if !ok {
				// Channel closed, we need to shut down
				tLog.Debug("client.sendExt, channel not okay", "id", c.ID)
				break sendLoop
			}
			if err := c.WS.SetWriteDeadline(
				time.Now().Add(writeTimeout)); err != nil {
				// Write error, shut down
				tLog.Debug("client.sendExt, deadline1 error", "id", c.ID, "err", err)
				break sendLoop
			}
			if err := c.WS.WriteJSON(m.Env); err != nil {
				// Write error, shut down
				tLog.Debug("client.sendExt, write1 error", "id", c.ID, "err", err)
				break sendLoop
			}
		case <-c.pinger.C:
			tLog.Debug("client.sendExt, got ping", "id", c.ID)
			if err := c.WS.SetWriteDeadline(
				time.Now().Add(writeTimeout)); err != nil {
				// Write error, shut down
				tLog.Debug("client.sendExt, deadline2 error", "id", c.ID, "err", err)
				break sendLoop
			}
			if err := c.WS.WriteMessage(
				websocket.PingMessage, nil); err != nil {
				// Ping write error, shut down
				tLog.Debug("client.sendExt, write2 error", "id", c.ID, "err", err)
				break sendLoop
			}
		}
	}

	// We are here due to either the channel being closed or the
	// network connection being closed. We need to make sure both are
	// true before continuing the shut down.
	tLog.Debug("client.sendExt, closing conn", "id", c.ID)
	c.WS.Close()
	c.pinger.Stop()
	tLog.Debug("client.sendExt, waiting for channel close", "id", c.ID)
	for {
		if _, ok := <-c.Pending; !ok {
			break
		}
	}

	// We're done. Tell the superhub we're done with the hub
	tLog.Debug("client.sendExt, releasing hub", "id", c.ID)
	Shub.Release(c.Hub)
}
