// Copyright 2020 Nik Silver
//
// Licensed under the GPL v3.0. See file LICENCE.txt for details.

package main

import (
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/gorilla/websocket"
	"github.com/inconshreveable/log15"
	"github.com/niksilver/board-game-framework/log"
)

// tLog is a logger for our tests only.
//
// Use it like this:
//     tLog.Info("This is my message", "key", value,...)
var tLog = log.Log.New("test", true)

func init() {
	// Accept only log messages that are from test
	filter := func(r *log15.Record) bool {
		for i := 0; i < len(r.Ctx); i += 2 {
			if r.Ctx[i] == "test" {
				return r.Ctx[i+1] == true
			}
		}
		return false
	}
	tLog.SetHandler(
		log15.FilterHandler(filter, log15.StdoutHandler),
	)
}

// newTestServer creates a new server to connect to, using the given handler.
func newTestServer(hdlr http.HandlerFunc) *httptest.Server {
	return httptest.NewServer(http.HandlerFunc(hdlr))
}

// dial connects to a test server, sending a clientID (if non-empty).
func dial(serv *httptest.Server, clientID string) (
	ws *websocket.Conn,
	resp *http.Response,
	err error,
) {
	// Convert http://a.b.c.d to ws://a.b.c.d
	url := "ws" + strings.TrimPrefix(serv.URL, "http")

	// If necessary, creater a header with the given cookie
	var header http.Header
	if clientID != "" {
		header = cookieRequestHeader("clientID", clientID)
	}

	// Connect to the server

	return websocket.DefaultDialer.Dial(url, header)
}

// cookieRequestHeader returns a new http.Header for a client request,
// in which only a single cookie is sent, with some value.
func cookieRequestHeader(name string, value string) http.Header {
	cookie := &http.Cookie{
		Name:  name,
		Value: value,
	}
	cookieStr := cookie.String()
	header := http.Header(make(map[string][]string))
	header.Add("Cookie", cookieStr)

	return header
}

// waitForEmptyHub wait for up to 2 seconds for the hub to be emptied
// or reports an test failure.
func waitForEmptyHub(desc string, h *Hub, t *testing.T) {
	deadline := time.Now().Add(2 * time.Second)
	for h.NumClients() > 0 {
		if time.Now().After(deadline) {
			t.Errorf("%s: Timeout waiting for hub to empty", desc)
			break
		}
	}
}

// waitForClientInHub waits for the named client to be added to the hub.
func waitForClient(h *Hub, id string) {
	for !h.HasClient(id) {
		// Go round again
	}
}

// readIntentMessage expects the next message to be of the given intent.
// It returns an error if not, or if it gets an error.
// It will only wait 500ms to read any message.
func readIntentMessage(ws *websocket.Conn, intent string) error {
	var env Envelope
	err := ws.SetReadDeadline(time.Now().Add(500 * time.Millisecond))
	if err != nil {
		return err
	}
	_, msg, err := ws.ReadMessage()
	if err != nil {
		return err
	}
	err = json.Unmarshal(msg, &env)
	if err != nil {
		return err
	}
	if env.Intent != intent {
		return fmt.Errorf(
			"Expected intent '%s' but got '%s'", intent, env.Intent,
		)
	}
	return nil
}

// readPeerMessage is like websocket's ReadMessage, but if it successfully
// reads a message whose intent is not "Peer" it will try again. If it
// gets an error, it will return that. It will only wait
//`timeout` milliseconds to read any message.
func readPeerMessage(ws *websocket.Conn, timeout int) (int, []byte, error) {
	var env Envelope
	for {
		err := ws.SetReadDeadline(
			time.Now().Add(time.Duration(timeout) * time.Millisecond),
		)
		if err != nil {
			return 0, []byte{}, err
		}
		mType, msg, err := ws.ReadMessage()
		if err != nil {
			return mType, msg, err
		}
		err = json.Unmarshal(msg, &env)
		if err != nil {
			return 0, []byte{}, err
		}
		if env.Intent == "Peer" {
			return mType, msg, err
		}
	}
}

// expectNoMessage expects no message within a timeout period (milliseconds).
// If it gets one it returns an error.
func expectNoMessage(ws *websocket.Conn, timeout int) error {
	err := ws.SetReadDeadline(
		time.Now().Add(time.Duration(timeout) * time.Millisecond),
	)
	if err != nil {
		return err
	}
	_, msg, err := ws.ReadMessage()
	if err != nil && strings.Contains(err.Error(), "timeout") {
		return nil
	}
	if err != nil {
		return fmt.Errorf("Got non-timeout error: %s", err.Error())
	}
	return fmt.Errorf("Wrongly got message '%s'", string(msg))
}
