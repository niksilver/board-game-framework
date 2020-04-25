// Copyright 2020 Nik Silver
//
// Licensed under the GPL v3.0. See file LICENCE.txt for details.

package main

import (
	"fmt"
	"testing"
	"time"

	"github.com/gorilla/websocket"
)

func TestClient_CreatesNewID(t *testing.T) {
	serv := newTestServer(echoHandler)
	defer serv.Close()

	ws, resp, err := dial(serv, "")
	defer ws.Close()
	if err != nil {
		t.Fatal(err)
	}

	cookies := resp.Cookies()
	clientID := ClientID(cookies)
	if clientID == "" {
		t.Errorf("clientID cookie is empty or not defined")
	}
}

func TestClient_ClientIDCookieIsPersistent(t *testing.T) {
	serv := newTestServer(echoHandler)
	defer serv.Close()

	ws, resp, err := dial(serv, "")
	defer ws.Close()
	if err != nil {
		t.Fatal(err)
	}

	cookies := resp.Cookies()
	maxAge := ClientIDMaxAge(cookies)
	if maxAge < 100_000 {
		t.Errorf(
			"clientID cookie has max age %d, but expected 100,000 or more",
			maxAge,
		)
	}
}

func TestClient_ReusesOldId(t *testing.T) {
	serv := newTestServer(echoHandler)
	defer serv.Close()

	initialClientID := "existing_value"

	ws, resp, err := dial(serv, initialClientID)
	defer ws.Close()
	if err != nil {
		t.Fatal(err)
	}

	cookies := resp.Cookies()
	clientID := ClientID(cookies)
	if clientID != initialClientID {
		t.Errorf("clientID cookie: expected '%s', got '%s'",
			clientID,
			initialClientID)
	}
}

func TestClient_NewIDsAreDifferent(t *testing.T) {
	usedIDs := make(map[string]bool)

	serv := newTestServer(echoHandler)
	defer serv.Close()

	for i := 0; i < 100; i++ {
		// Get a new client connection
		ws, resp, err := dial(serv, "")
		defer ws.Close()
		if err != nil {
			t.Fatal(err)
		}

		cookies := resp.Cookies()
		clientID := ClientID(cookies)

		if usedIDs[clientID] {
			t.Errorf("Iteration i = %d, clientID '%s' already used",
				i,
				clientID)
			return
		}
		if clientID == "" {
			t.Errorf("Iteration i = %d, clientID not set", i)
			return
		}

		usedIDs[clientID] = true
	}
}

func TestClient_SendsPings(t *testing.T) {
	// We'll send pings every 500ms, and wait for 3 seconds to receive
	// at least three of them.
	pingFrequency = 500 * time.Millisecond
	pings := 0

	serv := newTestServer(echoHandler)
	defer serv.Close()

	ws, _, err := dial(serv, "pingtester")
	defer ws.Close()
	if err != nil {
		t.Fatal(err)
	}

	// Wait for the client to have connected
	waitForClient(hub, "pingtester")

	// Set a timer for 3 seconds
	timeout := time.After(3 * time.Second)

	// A system for listening to the websocket
	var pingC chan bool
	var errC chan error
	go func() {
		for {
			mType, _, err := ws.ReadMessage()
			if err != nil {
				errC <- err
				break
			}
			if mType == websocket.PingMessage {
				pingC <- true
			} else {
				fmt.Errorf("Read non-ping message: type %d", mType)
				break
			}
		}
	}()

	// Now loop until we get three pings, an error, or a timeout
pingLoop:
	for {
		select {
		case <-pingC:
			pings += 1
			if pings == 3 {
				break pingLoop
			}
		case <-errC:
			t.Errorf("Read error '%s'", err.Error())
			break pingLoop
		case <-timeout:
			t.Errorf("Timeout waiting for ping")
			break pingLoop
		}
	}

	if pings < 3 {
		t.Errorf("Expected at least 3 pings but got %d", pings)
	}
}
