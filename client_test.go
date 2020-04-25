// Copyright 2020 Nik Silver
//
// Licensed under the GPL v3.0. See file LICENCE.txt for details.

package main

import (
	"strings"
	"testing"
	"time"

	"github.com/gorilla/websocket"
)

func TestClient_CreatesNewID(t *testing.T) {
	tLog.Info("Inside TestClient_CreatesNewID")
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
	tLog.Debug("TestClient_NewIDsAreDifferent(): Entering")
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

func TestClient_BouncesToOtherClients(t *testing.T) {
	tLog.Debug("TestClient_BouncesToOtherClients(): Entering")
	serv := newTestServer(echoHandler)
	defer serv.Close()

	// Connect 3 clients

	ws1, _, err := dial(serv, "CL1")
	defer ws1.Close()
	if err != nil {
		t.Fatal(err)
	}

	ws2, _, err := dial(serv, "CL2")
	defer ws2.Close()
	if err != nil {
		t.Fatal(err)
	}

	ws3, _, err := dial(serv, "CL3")
	defer ws3.Close()
	if err != nil {
		t.Fatal(err)
	}

	// Make sure all the clients have been added to hub.
	waitForClient(hub, "CL1")
	waitForClient(hub, "CL2")
	waitForClient(hub, "CL3")

	// Create 10 messages to send
	msgs := []string{
		"m0", "m1", "m2", "m3", "m4", "m5", "m6", "m7", "m8", "m9",
	}

	// Send 10 messages from client 1

	for i := 0; i < 10; i++ {
		msg := []byte(msgs[i])
		if err := ws1.WriteMessage(websocket.BinaryMessage, msg); err != nil {
			t.Fatalf("Write error for message %d: %s", i, err)
		}
	}

	// We expect 10 messages to client 2 and client 3

	for i := 0; i < 10; i++ {
		// Get a message from client 2
		ws2.SetReadDeadline(time.Now().Add(time.Second))
		_, rcvMsg, rcvErr := ws2.ReadMessage()
		if rcvErr != nil {
			t.Fatalf("Read error, ws2, i=%d: %s", i, rcvErr.Error())
		}
		if string(rcvMsg) != string(msgs[i]) {
			t.Errorf("ws2, i=%d, received '%s' but expected '%s'",
				i, rcvMsg, msgs[i],
			)
		}

		// Get a message from client 3
		ws3.SetReadDeadline(time.Now().Add(time.Second))
		_, rcvMsg, rcvErr = ws3.ReadMessage()
		if rcvErr != nil {
			t.Fatalf("Read error, ws3, i=%d: %s", i, rcvErr.Error())
		}
		if string(rcvMsg) != string(msgs[i]) {
			t.Errorf("ws3, i=%d, received '%s' but expected '%s'",
				i, rcvMsg, msgs[i],
			)
		}
	}

	// We expect no messages from client 1. It should timeout while waiting

	ws1.SetReadDeadline(time.Now().Add(time.Second))
	_, rcvMsg, rcvErr := ws1.ReadMessage()
	switch {
	case rcvErr == nil:
		t.Fatalf("Should not have received message, got '%s'", rcvMsg)
	case strings.Contains(rcvErr.Error(), "timeout"):
		// This is what we want
	default:
		t.Fatal("Got ws1 read error, but it wasn't a timeout: ", rcvErr)
	}
}
