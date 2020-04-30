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

// tConn is a websocket.Conn whose ReadMessage can time out safely
type tConn struct {
	ws      *websocket.Conn
	readRes chan readRes
}

// A combined ReadMessage result that can be put into a channel.
type readRes struct {
	mType int
	msg   []byte
	err   error
}

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

/*func setNoReadDeadline(ws *websocket.Conn) {
	err := ws.SetReadDeadline(time.Time{})
	if err != nil {
		panic(err.Error())
	}
}*/

// newTConn creates a new timeoutable connection from the given one.
func newTConn(ws *websocket.Conn) *tConn {
	return &tConn{
		ws: ws,
		// If this is not nil it means a readMessage call is in flight
		readRes: nil,
	}
}

// readMessage is like websocket.ReadMessage, but it can time out safely
// using the timeout given, in milliseconds. It returns the result of the
// read and false (no timeout), or a zero value and true (timed out).
// The result of the read may still include a read error.
// If using a `tConn` to read and if it times out, then the next
// read should also be using the `tConn`, not the usual `websocket.Conn`,
// because behind the scenes the read operation will still be in progress.
func (c *tConn) readMessage(timeout int) (readRes, bool) {
	if c.readRes == nil {
		// We're not already running a read, so let's start one
		c.readRes = make(chan readRes)
		go func() {
			mType, msg, err := c.ws.ReadMessage()
			c.readRes <- readRes{mType, msg, err}
		}()
	}
	// Now wait for a result or a timeout
	timeoutC := time.After(time.Duration(timeout) * time.Millisecond)
	select {
	case rr := <-c.readRes:
		// We've got a result from the readMessage operation
		c.readRes = nil
		return rr, false
	case <-timeoutC:
		// We timed out
		return readRes{}, true
	}
}

// swallowIntentMessage expects the next message to be of the given intent.
// It returns an error if not, or if it gets an error.
// It will only wait 500 ms to read any message.
// If there's an error, then future reads must be from the `tConn`,
// not the `websocket.Conn`, because a "timed out" error will mean there
// is still a read operation pending, and the `tConn` can handle that.
func (ws *tConn) swallowIntentMessage(intent string) error {
	var env Envelope
	rr, timedOut := ws.readMessage(500)
	if timedOut {
		return fmt.Errorf("readMessage timed out")
	}
	if rr.err != nil {
		return rr.err
	}
	err := json.Unmarshal(rr.msg, &env)
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
// If there's an error, then future reads must be from the `tConn`,
// not the `websocket.Conn`, because a "timed out" error will mean there
// is still a read operation pending, and the `tConn` can handle that.
func (ws *tConn) readPeerMessage(timeout int) (int, []byte, error) {
	var env Envelope
	for {
		rr, timedOut := ws.readMessage(timeout)
		if timedOut {
			return 0, []byte{}, fmt.Errorf("readMessage timed out")
		}
		if rr.err != nil {
			return rr.mType, rr.msg, rr.err
		}
		err := json.Unmarshal(rr.msg, &env)
		if err != nil {
			return 0, []byte{}, err
		}
		if env.Intent == "Peer" {
			return rr.mType, rr.msg, nil
		}
	}
}

// expectNoMessage expects no message within a timeout period (milliseconds).
// If it gets one it returns an error.
// If this function returns nil, then future reads must be from the `tConn`,
// not the `websocket.Conn`, because that means the read timed out, so there
// is still a read operation pending, and the `tConn` can handle that.
func (ws *tConn) expectNoMessage(timeout int) error {
	rr, timedOut := ws.readMessage(timeout)
	if timedOut {
		return nil
	}
	if rr.err != nil {
		return fmt.Errorf("Got non-timeout error: %s", rr.err.Error())
	}
	return fmt.Errorf("Wrongly got message '%s'", string(rr.msg))
}
