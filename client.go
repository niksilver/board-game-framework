// Copyright 2020 Nik Silver
//
// Licensed under the GPL v3.0. See file LICENCE.txt for details.

package main

import (
	"encoding/json"
	"fmt"
	"math/rand"
	"net/http"
	"time"

	"github.com/gorilla/websocket"
	"github.com/inconshreveable/log15"
	"github.com/niksilver/board-game-framework/log"
)

// How often we send pings
var pingFreq = 60 * time.Second

// How long we time out waiting for a pong or other data. Must be more
// than pingFreq.
var pongTimeout = (pingFreq * 5) / 4

// How long to allow to write to the websocket.
var writeTimeout = 10 * time.Second

type Client struct {
	ID string
	// Don't close the websocket directly. Use the Stop() method.
	Websocket *websocket.Conn
	Hub       *Hub
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
	cookie := &http.Cookie{
		Name:   "clientID",
		Value:  clientID,
		MaxAge: 60 * 60 * 24 * 365 * 100, // 100 years
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
	if c.log == nil {
		c.log = log.Log.New("ID", c.ID)
	}

	c.pinger = time.NewTicker(pingFreq)
	c.Websocket.SetReadDeadline(time.Now().Add(pongTimeout))
	c.Websocket.SetPongHandler(func(string) error {
		c.Websocket.SetReadDeadline(time.Now().Add(pongTimeout))
		return nil
	})

	c.Hub.Add(c)
	go c.receiveExt()
	go c.receiveInt()
}

// receiveExt is a goroutine that acts on external messages coming in.
func (c *Client) receiveExt() {
	defer c.Websocket.Close()

	// Read messages until we can no more
	for {
		mType, msg, err := c.Websocket.ReadMessage()
		if err != nil {
			c.log.Warn(
				"ReadMessage",
				"error", err,
			)
			break
		}
		// Currently ignores message type
		c.Hub.Pending <- &Message{
			From:  c,
			MType: mType,
			Env:   &Envelope{Body: msg},
		}
	}

	c.stop()
}

// receiveInt is a goroutine that acts on messages that have come from
// a hub (internally), and sends them out.
func (c *Client) receiveInt() {
	// Keep receiving internal messages
intLoop:
	for {
		select {
		case m, ok := <-c.Pending:
			if !ok {
				// Stop request received, acknowledged and acted on
				break intLoop
			}
			if err := c.Websocket.SetWriteDeadline(
				time.Now().Add(writeTimeout),
			); err != nil {
				c.log.Warn(
					"WriteMessage msg",
					"ID", c.ID,
					"error", err,
				)
				break intLoop
			}
			envBytes, err := json.Marshal(m.Env)
			if err != nil {
				// This means some internal coding mistake
				c.log.Error(
					"Envelope marshalling error",
					"ID", c.ID,
					"envelope", m.Env,
					"error", err,
				)
			}
			if err := c.Websocket.WriteMessage(m.MType, envBytes); err != nil {
				c.log.Warn(
					"WriteMessage msg",
					"ID", c.ID,
					"error", err,
				)
				break intLoop
			}
		case <-c.pinger.C:
			if err := c.Websocket.SetWriteDeadline(
				time.Now().Add(writeTimeout),
			); err != nil {
				c.log.Warn(
					"WriteMessage msg",
					"ID", c.ID,
					"error", err,
				)
				break intLoop
			}
			if err := c.Websocket.WriteMessage(
				websocket.PingMessage, nil,
			); err != nil {
				c.log.Warn(
					"WriteMessage ping",
					"ID", c.ID,
					"error", err,
				)
				break intLoop
			}
		}
	}

	c.stop()
}

// stop will stop the client without blocking any other goroutines, either
// in the client or the hub.
func (c *Client) stop() {
	c.pinger.Stop()

	// Make a stop request in a non-blocking way
makeRequest:
	for {
		select {
		case _, ok := <-c.Pending:
			// We're not interested in incoming message, so just swallow them.
			// But perhaps the channel is closed, meaning an earlier stop
			// has been acknowoledged.
			if !ok {
				break makeRequest
			}
		case c.Hub.stopReq <- c:
			// We've successfully sent a stop request to the hub.
			break makeRequest
		}
	}

	// Stop request has been made, maybe acknowledged
	for {
		if _, ok := <-c.Pending; !ok {
			break
		}
	}

	// Stop request acknowledged and acted on
	c.Websocket.Close()
}
