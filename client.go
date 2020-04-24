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
	"github.com/niksilver/board-game-framework/log"
)

type Client struct {
	ID        string
	Websocket *websocket.Conn
	Hub       *Hub
	Pending   chan *Message
	log       log15.Logger
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
// is sent. The ID will be newly-generated if the supplied one is empty.
func Upgrade(
	w http.ResponseWriter,
	r *http.Request,
	clientID string,
) (*websocket.Conn, error) {

	if clientID == "" {
		clientID = NewClientID()
	}

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
// if there's none there
func ClientID(cookies []*http.Cookie) string {
	for _, cookie := range cookies {
		if cookie.Name == "clientID" {
			return cookie.Value
		}
	}

	return ""
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

// Start attaches the client to its hub and starts it running.
func (c *Client) Start() {
	if c.log == nil {
		c.log = log.Log.New("ID", c.ID)
	}
	c.Hub.Add(c)
	go c.receiveExt()
	go c.receiveInt()
}

// receiveExt is a goroutine that acts on external messages coming in.
func (c *Client) receiveExt() {
	defer c.Websocket.Close()

	for {
		c.log.Debug(
			"c.receiveExt(), about to ReadMessage()",
		)
		mType, msg, err := c.Websocket.ReadMessage()
		c.log.Debug(
			"c.receiveExt(), got ReadMessage()",
		)
		if err != nil {
			c.log.Warn(
				"ReadMessage",
				"error", err,
			)
			break
		}
		// Currently ignores message type
		c.log.Debug(
			"c.receiveExt(), sending message to hub channel Pending",
			"c.Hub.Pending", c.Hub.Pending,
		)
		c.Hub.Pending <- &Message{
			From:  c,
			MType: mType,
			Msg:   msg,
		}
		c.log.Debug(
			"c.receiveExt(), sent message to hub channel Pending",
		)
	}
}

// receiveInt is a goroutine that acts on messages that have come from
// a hub (internally), and sends them out.
func (c *Client) receiveInt() {
	c.log.Debug(
		"c.receiveInt(), entering",
	)
	for {
		c.log.Debug(
			"c.receiveInt(), waiting on own channel Pending",
		)
		m := <-c.Pending
		c.log.Debug(
			"c.receiveInt(), received from own channel Pending",
		)
		if err := c.Websocket.WriteMessage(m.MType, m.Msg); err != nil {
			c.log.Warn(
				"WriteMessage",
				"error", err,
			)
			break
		}
	}
}
