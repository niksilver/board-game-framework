// Copyright 2020 Nik Silver
//
// Licensed under the GPL v3.0. See file LICENCE.txt for details.

package main

import (
	"encoding/json"
	"github.com/gorilla/websocket"
	"sync"
	"testing"
	"time"
)

func TestClient_CreatesNewID(t *testing.T) {
	serv := newTestServer(bounceHandler)
	defer serv.Close()

	ws, resp, err := dial(serv, "/cl.creates.new.id", "")
	defer ws.Close()
	if err != nil {
		t.Fatal(err)
	}

	cookies := resp.Cookies()
	clientID := ClientID(cookies)
	if clientID == "" {
		t.Errorf("clientID cookie is empty or not defined")
	}

	// Tidy up, and check everything in the main app finishes
	ws.Close()
	WG.Wait()
}

func TestClient_ClientIDCookieIsPersistent(t *testing.T) {
	serv := newTestServer(bounceHandler)
	defer serv.Close()

	ws, resp, err := dial(serv, "/cl.client.id.cookie.persistent", "")
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

	// Tidy up, and check everything in the main app finishes
	ws.Close()
	WG.Wait()
}

func TestClient_ReusesOldId(t *testing.T) {
	serv := newTestServer(bounceHandler)
	defer serv.Close()

	initialClientID := "existing_value"

	ws, resp, err := dial(serv, "/cl.reuses.old.id", initialClientID)
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

	// Tidy up, and check everything in the main app finishes
	ws.Close()
	WG.Wait()
}

func TestClient_NewIDsAreDifferent(t *testing.T) {
	usedIDs := make(map[string]bool)
	cIDs := make([]string, 100)
	wss := make([]*websocket.Conn, 100)

	serv := newTestServer(bounceHandler)
	defer serv.Close()

	for i := 0; i < len(wss); i++ {
		// Get a new client connection
		ws, resp, err := dial(serv, "/cl.new.ids.different", "")
		wss[i] = ws
		defer wss[i].Close()
		if err != nil {
			t.Fatal(err)
		}

		cookies := resp.Cookies()
		clientID := ClientID(cookies)
		cIDs[i] = clientID

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

	// Tidy up, and check everything in the main app finishes
	for _, ws := range wss {
		ws.Close()
	}
	WG.Wait()
}

func TestClient_SendsPings(t *testing.T) {
	// We'll send pings every 500ms, and wait for 3 seconds to receive
	// at least three of them.
	oldPingFreq := pingFreq
	pingFreq = 500 * time.Millisecond
	pings := 0

	serv := newTestServer(bounceHandler)
	defer func() {
		pingFreq = oldPingFreq
		serv.Close()
	}()

	ws, _, err := dial(serv, "/cl.sends.pings", "pingtester")
	defer ws.Close()
	if err != nil {
		t.Fatal(err)
	}
	tws := newTConn(ws, "pingtester")

	// Signal pings
	pingC := make(chan bool)
	ws.SetPingHandler(func(string) error {
		pingC <- true
		return nil
	})

	// Set a timer for 3 seconds
	timeout := time.After(3 * time.Second)

	// We'll assume the client connects reasonably quickly

	// In the background loop until we get three pings, an error, or a timeout
	w := sync.WaitGroup{}
	w.Add(1)
	go func() {
		defer w.Done()
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

	w.Wait()

	// Tidy up, and check everything in the main app finishes
	ws.Close()
	WG.Wait()
}

func TestClient_DisconnectsIfNoPongs(t *testing.T) {
	// Give the bounceHandler a very short pong timeout (just for this test)
	oldPongTimeout := pongTimeout
	pongTimeout = 500 * time.Millisecond

	serv := newTestServer(bounceHandler)
	defer func() {
		pongTimeout = oldPongTimeout
		serv.Close()
	}()

	ws, _, err := dial(serv, "/cl.if.no.pongs", "pongtester")
	defer ws.Close()
	if err != nil {
		t.Fatal(err)
	}
	tws := newTConn(ws, "pongtester")

	// Wait for the client to have connected, and swallow the "Welcome"
	// message
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

	// Tidy up, and check everything in the main app finishes
	ws.Close()
	WG.Wait()
}

// It might be that when a client joins there is already a client with
// the same ID in the game. This will happen if the same user opens another
// browser to the same game, and hence reuses the ID cookie.
// In this case the From and To fields in both welcome and joiner envelopes
// will contain duplicates.
func TestClient_DuplicateIDsInFromAndToIfClientJoinsTwice(t *testing.T) {
	serv := newTestServer(bounceHandler)
	defer serv.Close()

	// Connect 3 clients in turn. Each existing client should
	// receive a joiner message about each new client.

	game := "/cl.dupe.ids"

	// Connect the first client, and consume the welcome message
	ws1, _, err := dial(serv, game, "DUP1")
	defer ws1.Close()
	if err != nil {
		t.Fatal(err)
	}
	tws1 := newTConn(ws1, "DUP1")
	if err = swallowMany(
		intentExp{"WF1 joining, ws1", tws1, "Welcome"},
	); err != nil {
		t.Fatal(err)
	}

	// Connect the second client (will be duped), and consume intro messages
	ws2a, _, err := dial(serv, game, "DUP2")
	defer ws2a.Close()
	if err != nil {
		t.Fatal(err)
	}
	tws2a := newTConn(ws2a, "DUP2(a)")
	if err = swallowMany(
		intentExp{"DUP2 joining (a), ws2a", tws2a, "Welcome"},
		intentExp{"DUP2 joining (a), ws1", tws1, "Joiner"},
	); err != nil {
		t.Fatal(err)
	}

	// Connect the third client, which is reusing the ID of the second
	ws2b, _, err := dial(serv, game, "DUP2")
	defer ws2b.Close()
	if err != nil {
		t.Fatal(err)
	}
	tws2b := newTConn(ws2b, "DUP2(b)")

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

	// Tidy up, and check everything in the main app finishes
	ws1.Close()
	ws2a.Close()
	ws2b.Close()
	WG.Wait()
}

func TestClient_ExcessiveMessageWillCloseConnection(t *testing.T) {
	serv := newTestServer(bounceHandler)
	defer serv.Close()

	// Connect the client, and consume the welcome message
	ws, _, err := dial(serv, "/cl.excess.message", "EXCESS1")
	defer ws.Close()
	if err != nil {
		t.Fatal(err)
	}
	tws := newTConn(ws, "EXCESS1")
	if err = swallowMany(
		intentExp{"WF1 joining", tws, "Welcome"},
	); err != nil {
		t.Fatal(err)
	}

	// Create 100k message, and send that. It should fail at some point
	msg := make([]byte, 100*1024)
	err = ws.WriteMessage(websocket.BinaryMessage, msg)
	if err != nil {
		// We got an error, and that's probably okay
	}

	// Reading should tell us the connection has been closed by peer
	rr, timedOut := tws.readMessage(500)
	if timedOut {
		t.Fatal("Timed out reading, but should have got an immediate close")
	}
	if rr.err == nil {
		t.Fatal("Didn't get an error reading connection, which is wrong")
	}
	// We got an error, and that's good.
	if websocket.IsCloseError(rr.err, websocket.CloseMessageTooBig) {
		// The right error
	} else {
		t.Errorf(
			"Got an error reading, but it was the wrong one: %s",
			rr.err.Error(),
		)
	}

	// Tidy up, and check everything in the main app finishes
	ws.Close()
	WG.Wait()
}
