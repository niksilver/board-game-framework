// Copyright 2020 Nik Silver
//
// Licensed under the GPL v3.0. See file LICENCE.txt for details.

package main

import (
	"encoding/json"
	"testing"
	"time"
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
	// Reset the global hub
	hub = NewHub()
	hub.Start()

	// We'll send pings every 500ms, and wait for 3 seconds to receive
	// at least three of them.
	oldPingFreq := pingFreq
	pingFreq = 500 * time.Millisecond
	pings := 0

	serv := newTestServer(echoHandler)
	defer func() {
		pingFreq = oldPingFreq
		serv.Close()
	}()

	ws, _, err := dial(serv, "pingtester")
	defer ws.Close()
	if err != nil {
		t.Fatal(err)
	}
	tws := newTConn(ws)

	// Signal pings
	pingC := make(chan bool)
	ws.SetPingHandler(func(string) error {
		pingC <- true
		return nil
	})

	// Set a timer for 3 seconds
	timeout := time.After(3 * time.Second)

	// Wait for the client to have connected
	waitForClient(hub, "pingtester")

	// In the background loop until we get three pings, an error, or a timeout
	go func() {
	pingLoop:
		for {
			select {
			case <-pingC:
				pings += 1
				if pings == 3 {
					break pingLoop
				}
			case <-timeout:
				t.Errorf("Timeout waiting for ping")
				break pingLoop
			}
		}
		ws.Close()
	}()

	// Read the connection, which will listen for pings
	// It will exit with a close error when the above code times out
	tws.readPeerMessage(10_000)

	if pings < 3 {
		t.Errorf("Expected at least 3 pings but got %d", pings)
	}
}

func TestClient_DisconnectsIfNoPongs(t *testing.T) {
	// Reset the global hub
	hub = NewHub()
	hub.Start()

	// Give the echoHandler a very short pong timeout (just for this test)
	oldPongTimeout := pongTimeout
	pongTimeout = 500 * time.Millisecond

	serv := newTestServer(echoHandler)
	defer func() {
		pongTimeout = oldPongTimeout
		serv.Close()
	}()

	ws, _, err := dial(serv, "pingtester")
	defer ws.Close()
	if err != nil {
		t.Fatal(err)
	}
	tws := newTConn(ws)

	// Wait for the client to have connected, and swallow the "Welcome"
	// message
	waitForClient(hub, "pingtester")
	if err := tws.swallowIntentMessage("Welcome"); err != nil {
		t.Fatal(err)
	}

	// Within 3 seconds we should get no message, and the peer should
	// close. It shouldn't time out.
	rr, timedOut := tws.readMessage(3000)
	if timedOut {
		t.Errorf("Too long waiting for peer to close")
	}
	if rr.err == nil {
		t.Errorf("Wrongly got data from peer")
	}
}

func TestClient_SendsWelcome(t *testing.T) {
	serv := newTestServer(echoHandler)
	defer serv.Close()

	// Connect to the server
	ws, _, err := dial(serv, "WTESTER")
	defer ws.Close()
	if err != nil {
		t.Fatal(err)
	}
	tws := newTConn(ws)

	// Read the next message, expected within 500ms
	rr, timedOut := tws.readMessage(500)
	if timedOut {
		t.Fatal("Timed out waiting for welcome message")
	}
	if rr.err != nil {
		t.Fatalf("Error waiting for welcome message: %s", rr.err.Error())
	}

	// Unwrap the message and check it

	env := Envelope{}
	err = json.Unmarshal(rr.msg, &env)
	if err != nil {
		t.Fatal(err)
	}

	if env.Intent != "Welcome" {
		t.Errorf("Message intent was '%s' but expected 'Welcome'", env.Intent)
	}
	if !sameElements(env.To, []string{"WTESTER"}) {
		t.Errorf(
			"Message To field was %v but expected [\"WTESTER\"]",
			env.To,
		)
	}
}

func TestClient_WelcomeIsFromExistingClients(t *testing.T) {
	// Reset the global hub
	hub = NewHub()
	hub.Start()

	serv := newTestServer(echoHandler)
	defer serv.Close()

	// Connect 3 clients in turn. Each existing client should
	// receive a joiner message about each new client.

	// Connect the first client, and consume the welcome message
	ws1, _, err := dial(serv, "WF1")
	defer ws1.Close()
	if err != nil {
		t.Fatal(err)
	}
	tws1 := newTConn(ws1)
	if err = swallowMany(
		intentExp{"WF1 joining, ws1", tws1, "Welcome"},
	); err != nil {
		t.Fatal(err)
	}

	// Connect the second client, and consume intro messages
	ws2, _, err := dial(serv, "WF2")
	defer ws2.Close()
	if err != nil {
		t.Fatal(err)
	}
	tws2 := newTConn(ws2)
	if err = swallowMany(
		intentExp{"WF2 joining, ws2", tws2, "Welcome"},
		intentExp{"WF2 joining, ws1", tws1, "Joiner"},
	); err != nil {
		t.Fatal(err)
	}

	// Connect the third client
	ws3, _, err := dial(serv, "WF3")
	defer ws3.Close()
	if err != nil {
		t.Fatal(err)
	}
	tws3 := newTConn(ws3)

	// Get what we expect to be the the welcome message
	rr, timedOut := tws3.readMessage(500)
	if timedOut {
		t.Fatal("Timed out reading message from ws3")
	}
	if err != nil {
		t.Fatal(err)
	}

	// Unwrap the message and check it

	env := Envelope{}
	err = json.Unmarshal(rr.msg, &env)
	if err != nil {
		t.Fatal(err)
	}

	if env.Intent != "Welcome" {
		t.Errorf("Message intent was '%s' but expected 'Welcome'", env.Intent)
	}
	if !sameElements(env.From, []string{"WF1", "WF2"}) {
		t.Errorf(
			"Message From field was %v but expected it to be [WF1, WF2]",
			env.From,
		)
	}
}

// It might be that when a client joins there is already a client with
// the same ID in the game. This will happen if the same user opens another
// browser to the same game, and hence reuses the ID cookie.
// In this case the From and To fields in both welcome and joiner envelopes
// will contain duplicates.
func TestClient_NoDuplicateIDsInFromAndToIfClientJoinsTwice(t *testing.T) {
	// Reset the global hub
	hub = NewHub()
	hub.Start()

	serv := newTestServer(echoHandler)
	defer serv.Close()

	// Connect 3 clients in turn. Each existing client should
	// receive a joiner message about each new client.

	// Connect the first client, and consume the welcome message
	ws1, _, err := dial(serv, "DUP1")
	defer ws1.Close()
	if err != nil {
		t.Fatal(err)
	}
	tws1 := newTConn(ws1)
	if err = swallowMany(
		intentExp{"WF1 joining, ws1", tws1, "Welcome"},
	); err != nil {
		t.Fatal(err)
	}

	// Connect the second client (will be duped), and consume intro messages
	ws2a, _, err := dial(serv, "DUP2")
	defer ws2a.Close()
	if err != nil {
		t.Fatal(err)
	}
	tws2a := newTConn(ws2a)
	if err = swallowMany(
		intentExp{"DUP2 joining (a), ws2a", tws2a, "Welcome"},
		intentExp{"DUP2 joining (a), ws1", tws1, "Joiner"},
	); err != nil {
		t.Fatal(err)
	}

	// Connect the third client, which is reusing the ID of the second
	ws2b, _, err := dial(serv, "DUP2")
	defer ws2b.Close()
	if err != nil {
		t.Fatal(err)
	}
	tws2b := newTConn(ws2b)

	// The first client should get a joiner message from the second
	// client (again). It should see the ID in the To and From fields.
	rr, timedOut := tws1.readMessage(500)
	if timedOut {
		t.Fatal("Timed out reading message from ws1")
	}
	if err != nil {
		t.Fatal(err)
	}
	// Unwrap the message and check it
	env := Envelope{}
	err = json.Unmarshal(rr.msg, &env)
	if err != nil {
		t.Fatal(err)
	}
	if env.Intent != "Joiner" {
		t.Errorf(
			"ws1: Message intent was '%s' but expected 'Joiner'", env.Intent,
		)
	}
	if !sameElements(env.From, []string{"DUP2"}) {
		t.Errorf(
			"ws1: Message From field was %v but expected [DUP2]",
			env.From,
		)
	}
	if !sameElements(env.To, []string{"DUP1", "DUP2"}) {
		t.Errorf(
			"ws1: Message To field was %v but expected [DUP1, DUP2]",
			env.From,
		)
	}

	// The second client should get a joiner message from the second
	// client. It should see its ID in the To and From fields.
	rr, timedOut = tws2a.readMessage(500)
	if timedOut {
		t.Fatal("Timed out reading message from ws2")
	}
	if err != nil {
		t.Fatal(err)
	}
	// Unwrap the message and check it
	env = Envelope{}
	err = json.Unmarshal(rr.msg, &env)
	if err != nil {
		t.Fatal(err)
	}
	if env.Intent != "Joiner" {
		t.Errorf(
			"ws2: Message intent was '%s' but expected 'Joiner'", env.Intent,
		)
	}
	if !sameElements(env.From, []string{"DUP2"}) {
		t.Errorf(
			"ws2: Message From field was %v but expected [DUP2]",
			env.From,
		)
	}
	if !sameElements(env.To, []string{"DUP1", "DUP2"}) {
		t.Errorf(
			"ws2: Message To field was %v but expected [DUP1, DUP2]",
			env.From,
		)
	}

	// The third client should get a welcome message.
	// It should see its ID in the To and From fields.
	rr, timedOut = tws2b.readMessage(500)
	if timedOut {
		t.Fatal("Timed out reading message from ws2")
	}
	if err != nil {
		t.Fatal(err)
	}
	// Unwrap the message and check it
	env = Envelope{}
	err = json.Unmarshal(rr.msg, &env)
	if err != nil {
		t.Fatal(err)
	}
	if env.Intent != "Welcome" {
		t.Errorf(
			"ws3: Message intent was '%s' but expected 'Welcome'", env.Intent,
		)
	}
	if !sameElements(env.From, []string{"DUP1", "DUP2"}) {
		t.Errorf(
			"ws3: Message From field was %v but expected [DUP1,DUP2]",
			env.From,
		)
	}
	if !sameElements(env.To, []string{"DUP2"}) {
		t.Errorf(
			"ws3: Message To field was %v but expected [DUP2]",
			env.From,
		)
	}
}
