// Copyright 2020 Nik Silver
//
// Licensed under the GPL v3.0. See file LICENCE.txt for details.

package main

import (
	"encoding/json"
	"math/rand"
	"strconv"
	"sync"
	"testing"
	"time"

	"github.com/gorilla/websocket"
)

func TestHub_BouncesToOtherClients(t *testing.T) {
	serv := newTestServer(bounceHandler)
	defer serv.Close()

	// Connect 3 clients
	// We'll make sure all the clients have been added to hub, and force
	// the order by waiting on messages.

	game := "/hub.bounces.to.other"

	// We'll want to check From, To and Time fields, as well as
	// message contents.
	// Because we have 3 clients we'll have 2 listed in the To field.

	// Client 1 joins normally

	ws1, _, err := dial(serv, game, "CL1")
	defer ws1.Close()
	if err != nil {
		t.Fatal(err)
	}
	tws1 := newTConn(ws1, "CL1")
	if err := tws1.swallowIntentMessage("Welcome"); err != nil {
		t.Fatalf("Welcome error for ws1: %s", err)
	}

	// Client 2 joins, and client 1 gets a joiner message

	ws2, _, err := dial(serv, game, "CL2")
	defer ws2.Close()
	if err != nil {
		t.Fatal(err)
	}
	tws2 := newTConn(ws2, "CL2")
	if err = swallowMany(
		intentExp{"CL2 joining, ws2", tws2, "Welcome"},
		intentExp{"CL2 joining, ws1", tws1, "Joiner"},
	); err != nil {
		t.Fatal(err)
	}

	// Client 3 joins, and clients 1 and 2 get joiner messages.

	ws3, _, err := dial(serv, game, "CL3")
	defer ws3.Close()
	if err != nil {
		t.Fatal(err)
	}
	tws3 := newTConn(ws3, "CL3")
	if err = swallowMany(
		intentExp{"CL3 joining, ws2", tws3, "Welcome"},
		intentExp{"CL3 joining, ws1", tws1, "Joiner"},
		intentExp{"CL3 joining, ws2", tws2, "Joiner"},
	); err != nil {
		t.Fatal(err)
	}

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
		rr, timedOut := tws2.readMessage(1000)
		if timedOut {
			t.Fatalf("Timed out reading ws2, i=%d", i)
		}
		if rr.err != nil {
			t.Fatalf("Read error, ws2, i=%d: %s", i, rr.err.Error())
		}
		env := Envelope{}
		err := json.Unmarshal(rr.msg, &env)
		if err != nil {
			t.Fatalf("Could not unmarshal '%s': %s", rr.msg, err.Error())
		}
		if string(env.Body) != string(msgs[i]) {
			t.Errorf("ws2, i=%d, received '%s' but expected '%s'",
				i, env.Body, msgs[i],
			)
		}

		// Get a message from client 3
		rr, timedOut = tws3.readMessage(1000)
		if timedOut {
			t.Fatalf("Timed out reading ws3, i=%d", i)
		}
		if rr.err != nil {
			t.Fatalf("Read error, ws3, i=%d: %s", i, rr.err.Error())
		}
		env = Envelope{}
		err = json.Unmarshal(rr.msg, &env)
		if err != nil {
			t.Fatalf("Could not unmarshal '%s': %s", rr.msg, err.Error())
		}
		if string(env.Body) != string(msgs[i]) {
			t.Errorf("ws3, i=%d, received '%s' but expected '%s'",
				i, env.Body, msgs[i],
			)
		}
	}

	// We expect no messages from client 1. It should timeout while waiting

	tLog.Debug("TestHub_BouncesToOtherClients, expecting no message")
	err = tws1.expectNoMessage(1000)
	if err != nil {
		t.Fatalf("Got something while expecting no message: %s", err.Error())
	}

	// Tidy up and check everything in the main app finishes
	tLog.Debug("TestHub_BouncesToOtherClients, closing off")
	tws1.close()
	tws2.close()
	tws3.close()
	tLog.Debug("TestHub_BouncesToOtherClients, waiting on group")
	wg.Wait()
}

func TestHub_BasicMessageEnvelopeIsCorrect(t *testing.T) {
	serv := newTestServer(bounceHandler)
	defer serv.Close()

	// Connect 3 clients.
	// We'll make sure all the clients have been added to hub, and force
	// the order by waiting on messages.

	game := "/hub.basic.envelope"

	// We'll want to check From, To and Time fields, as well as
	// message contents.
	// Because we have 3 clients we'll have 2 listed in the To field.

	// Client 1 joins normally

	ws1, _, err := dial(serv, game, "EN1")
	defer ws1.Close()
	if err != nil {
		t.Fatal(err)
	}
	tws1 := newTConn(ws1, "EN1")
	if err := tws1.swallowIntentMessage("Welcome"); err != nil {
		t.Fatalf("Welcome error for ws1: %s", err)
	}

	// Client 2 joins, and client 1 gets a joiner message

	ws2, _, err := dial(serv, game, "EN2")
	defer ws2.Close()
	if err != nil {
		t.Fatal(err)
	}
	tws2 := newTConn(ws2, "EN2")
	if err = swallowMany(
		intentExp{"EN2 joining, ws2", tws2, "Welcome"},
		intentExp{"EN2 joining, ws1", tws1, "Joiner"},
	); err != nil {
		t.Fatal(err)
	}

	// Client 3 joins, and clients 1 and 2 get joiner messages.

	ws3, _, err := dial(serv, game, "EN3")
	defer ws3.Close()
	if err != nil {
		t.Fatal(err)
	}
	tws3 := newTConn(ws3, "EN3")
	if err = swallowMany(
		intentExp{"EN3 joining, ws3", tws3, "Welcome"},
		intentExp{"EN3 joining, ws1", tws1, "Joiner"},
		intentExp{"EN3 joining, ws2", tws2, "Joiner"},
	); err != nil {
		t.Fatal(err)
	}

	// Send a message, then pick up the results from one of the clients

	err = ws1.WriteMessage(
		websocket.BinaryMessage, []byte("Can you read me?"),
	)
	if err != nil {
		t.Fatalf("Error writing message: %s", err.Error())
	}

	rr, timedOut := tws2.readMessage(500)
	if timedOut {
		t.Fatal("Timed out trying to read message")
	}
	if rr.err != nil {
		t.Fatalf("Error reading message: %s", rr.err.Error())
	}

	env := Envelope{}
	err = json.Unmarshal(rr.msg, &env)
	if err != nil {
		t.Fatalf(
			"Couldn't unmarshal message '%s'. Error %s",
			rr.msg, err.Error(),
		)
	}

	// Test fields...

	// Body field
	if string(env.Body) != "Can you read me?" {
		t.Errorf("Envelope body not as expected, got '%s'", env.Body)
	}

	// From field
	if !sameElements(env.From, []string{"EN1"}) {
		t.Errorf("Got envelope From '%s' but expected ['EN1']", env.From)
	}

	// To field
	if !sameElements(env.To, []string{"EN2", "EN3"}) {
		t.Errorf(
			"Envelope To was '%v' but expected it be just EN2 and EN3",
			env.To,
		)
	}

	// Time field
	timeT := time.Unix(env.Time, 0) // Convert seconds back to Time(!)
	now := time.Now()
	recentPast := now.Add(-5 * time.Second)
	if timeT.Before(recentPast) || timeT.After(now) {
		t.Errorf(
			"Got time %v, which wasn't between %v and %v",
			timeT, recentPast, now,
		)
	}

	// Intent field
	if string(env.Intent) != "Peer" {
		t.Errorf("Envelope intent not as expected, got '%s', expected 'Peer", env.Intent)
	}

	// Tidy up and check everything in the main app finishes
	tLog.Debug("TestHub_BasicMessageEnvelopeIsCorrect, closing off")
	tws1.close()
	tws2.close()
	tws3.close()
	tLog.Debug("TestHub_BasicMessageEnvelopeIsCorrect, waiting on group")
	wg.Wait()
}

// A test for general connecting, disconnecting and message sending...
// This just needs to run and not deadlock.
func TestHub_GeneralChaos(t *testing.T) {
	rand.Seed(time.Now().UnixNano())
	cMap := make(map[string]*websocket.Conn)
	cSlice := make([]string, 0)
	consumed := 0

	// Start a web server
	serv := newTestServer(bounceHandler)
	defer serv.Close()

	// A client should consume messages until done
	w := sync.WaitGroup{}
	consume := func(ws *websocket.Conn, id string) {
		defer w.Done()
		for {
			_, _, err := ws.ReadMessage()
			if err == nil {
				consumed += 1
			} else {
				break
			}
		}
		ws.Close()
	}

	for i := 0; i < 100; i++ {
		action := rand.Float32()
		cCount := len(cSlice)
		switch {
		case i < 10 || action < 0.25:
			// New client join
			id := "CHAOS" + strconv.Itoa(i)
			ws, _, err := dial(serv, "/hub.chaos", id)
			defer func() {
				ws.Close()
			}()
			if err != nil {
				t.Fatalf("Couldn't dial, i=%d, error '%s'", i, err.Error())
			}
			cMap[id] = ws
			cSlice = append(cSlice, id)
			w.Add(1)
			go consume(ws, id)
		case cCount > 0 && action >= 0.25 && action < 0.35:
			// Some client leaves
			idx := rand.Intn(len(cSlice))
			id := cSlice[idx]
			ws := cMap[id]
			ws.Close()
			delete(cMap, id)
			cSlice = append(cSlice[:idx], cSlice[idx+1:]...)
		case cCount > 0:
			// Some client sends a message
			idx := rand.Intn(len(cSlice))
			id := cSlice[idx]
			ws := cMap[id]
			msg := "Message " + strconv.Itoa(i)
			err := ws.WriteMessage(websocket.BinaryMessage, []byte(msg))
			if err != nil {
				t.Fatalf(
					"Couldn't write message, i=%d, id=%s error '%s'",
					i, id, err.Error(),
				)
			}
		default:
			// Can't take any action
		}
	}

	// Close remaining connections and wait for test goroutines
	for _, ws := range cMap {
		ws.Close()
	}
	w.Wait()

	// Check everything in the main app finishes
	tLog.Debug("TestHub_GeneralChaos, waiting on group")
	wg.Wait()
}

func TestHub_JoinerMessagesHappen(t *testing.T) {
	serv := newTestServer(bounceHandler)
	defer serv.Close()

	// Connect 3 clients in turn. Each existing client should
	// receive a joiner message about each new client.

	game := "/hub.joiner.messages"

	// Connect the first client
	ws1, _, err := dial(serv, game, "JM1")
	defer ws1.Close()
	if err != nil {
		t.Fatal(err)
	}
	tws1 := newTConn(ws1, "JM1")
	if err := tws1.swallowIntentMessage("Welcome"); err != nil {
		t.Fatalf("Welcome error for ws1: %s", err)
	}

	// Connect the second client
	ws2, _, err := dial(serv, game, "JM2")
	defer ws2.Close()
	if err != nil {
		t.Fatal(err)
	}
	tws2 := newTConn(ws2, "JM2")
	if err := tws2.swallowIntentMessage("Welcome"); err != nil {
		t.Fatalf("Welcome error for ws2: %s", err)
	}

	// Expect a joiner message to ws1
	rr, timedOut := tws1.readMessage(500)
	if timedOut {
		t.Fatal("Timed out reading tws1")
	}
	if rr.err != nil {
		t.Fatal(err)
	}
	var env Envelope
	err = json.Unmarshal(rr.msg, &env)
	if err != nil {
		t.Fatal(err)
	}
	if env.Intent != "Joiner" {
		t.Fatalf("ws1 message isn't a joiner message. env is %#v", env)
	}
	if !sameElements(env.From, []string{"JM2"}) {
		t.Fatalf("ws1 got From field which wasn't JM2. env is %#v", env)
	}
	if !sameElements(env.To, []string{"JM1"}) {
		t.Fatalf("ws1 To field didn't contain just its ID. env is %#v", env)
	}
	if env.Time < time.Now().Unix() {
		t.Fatalf("ws1 got Time field in the past. env is %#v", env)
	}
	if env.Body != nil {
		t.Fatalf("ws1 got unexpected Body field. env is %#v", env)
	}

	// Expect no message to ws2
	err = tws2.expectNoMessage(500)
	if err != nil {
		t.Fatal(err)
	}

	// Connect the third client
	ws3, _, err := dial(serv, game, "JM3")
	defer ws3.Close()
	if err != nil {
		t.Fatal(err)
	}
	tws3 := newTConn(ws3, "JM3")
	if err := tws3.swallowIntentMessage("Welcome"); err != nil {
		t.Fatalf("Welcome error for tws3: %s", err)
	}

	// Expect a joiner message to ws1 (and shortly, ws2)
	rr, timedOut = tws1.readMessage(500)
	if timedOut {
		t.Fatal("Timed out reading tws1")
	}
	if rr.err != nil {
		t.Fatal(rr.err)
	}
	err = json.Unmarshal(rr.msg, &env)
	if err != nil {
		t.Fatal(err)
	}
	if env.Intent != "Joiner" {
		t.Fatalf("ws1 message isn't a joiner message. env is %#v", env)
	}
	if !sameElements(env.From, []string{"JM3"}) {
		t.Fatalf("ws1 got From field not with just JM3. env is %#v", env)
	}
	if !sameElements(env.To, []string{"JM1", "JM2"}) {
		t.Fatalf("ws1 To field didn't contain JM1 and JM2. env is %#v", env)
	}
	if env.Time > time.Now().Unix() {
		t.Fatalf("ws1 got Time field in the future. env is %#v", env)
	}
	if env.Body != nil {
		t.Fatalf("ws1 got unexpected Body field. env is %#v", env)
	}

	// Now check the joiner message to ws2
	rr, timedOut = tws2.readMessage(500)
	if timedOut {
		t.Fatal("Timed out reading tws2")
	}
	if rr.err != nil {
		t.Fatal(rr.err)
	}
	err = json.Unmarshal(rr.msg, &env)
	if err != nil {
		t.Fatal(err)
	}
	if env.Intent != "Joiner" {
		t.Fatalf("ws2 message isn't a joiner message. env is %#v", env)
	}
	if !sameElements(env.From, []string{"JM3"}) {
		t.Fatalf("ws2 got From field not with JM3. env is %#v", env)
	}
	if !sameElements(env.To, []string{"JM2", "JM1"}) {
		t.Fatalf("ws2 To field didn't contain JM1 and JM2. env is %#v", env)
	}
	if env.Time < time.Now().Unix() {
		t.Fatalf("ws2 got Time field in the past. env is %#v", env)
	}
	if env.Body != nil {
		t.Fatalf("ws2 got unexpected Body field. env is %#v", env)
	}

	// Expect no message to ws3
	err = tws3.expectNoMessage(500)
	if err != nil {
		t.Fatal(err)
	}
}
