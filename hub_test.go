// Copyright 2020 Nik Silver
//
// Licensed under the GPL v3.0. See file LICENCE.txt for details.

package main

import (
	"encoding/json"
	"sort"
	"strconv"
	"strings"
	"testing"
	"time"

	"github.com/gorilla/websocket"
)

func TestHub_CanAddAndGetClients(t *testing.T) {
	hub := NewHub()

	// A new Hub should have no clients
	len0 := len(hub.Clients())
	if len0 != 0 {
		t.Fatalf("New hub had %d clients but expected none", len0)
	}

	// Add one client and check the hub has only one client
	id1 := "id1"
	hub.Add(&Client{ID: id1})
	cl1 := hub.Clients()
	act1 := len(cl1)
	if act1 != 1 {
		t.Fatalf(
			"Client 1: Hub had %d clients but expected 1: %#v",
			act1,
			cl1,
		)
	}
	if cl1[0].ID != id1 {
		t.Fatalf(
			"Client 1: Hub's first client id was '%s' but expected '%s'",
			cl1[0].ID,
			id1,
		)
	}

	// Add a second client and check the hub has two clients
	id2 := "id2"
	hub.Add(&Client{ID: id2})
	cl2 := hub.Clients()
	act2 := len(cl2)
	if act2 != 2 {
		t.Fatalf("Client 2: Hub had %d clients but expected 2", act2)
	}

	// Check the two clients are what we expect them to be
	sort.Slice(cl2, func(i int, j int) bool { return cl2[i].ID < cl2[j].ID })
	if cl2[0].ID != id1 {
		t.Errorf(
			"Client 2: Hub's first client id was '%s' but expected '%s'",
			cl2[0].ID,
			id1,
		)
	}
	if cl2[1].ID != id2 {
		t.Errorf(
			"Client 2: Hub's second client id was '%s' but expected '%s'",
			cl2[1].ID,
			id2,
		)
	}
}

func TestHub_CanRemoveClients(t *testing.T) {
	hub := NewHub()
	c2 := &Client{ID: "id2"}
	hub.Add(&Client{ID: "id1"})
	hub.Add(c2)
	hub.Add(&Client{ID: "id3"})

	// Hub should now have 3 clients
	cs3 := hub.Clients()
	act3 := len(cs3)
	if act3 != 3 {
		t.Fatalf("Hub had %d clients but expected 3", act3)
	}

	// After removing one, hub should have 2 clients
	hub.Remove(c2)
	cs2 := hub.Clients()
	act2 := len(cs2)
	if act2 != 2 {
		t.Fatalf("Hub had %d clients but expected 2", act2)
	}

	// The two clients should be the ones we expect
	sort.Slice(cs2, func(i int, j int) bool { return cs2[i].ID < cs2[j].ID })
	if cs2[0].ID != "id1" {
		t.Errorf(
			"Hub's first client id was '%s' but expected 'id1'",
			cs2[0].ID,
		)
	}
	if cs2[1].ID != "id3" {
		t.Errorf(
			"Hub's second client id was '%s' but expected 'id3'",
			cs2[1].ID,
		)
	}
}

func TestHub_ClientReadWriteIsConcurrencySafe(t *testing.T) {
	hub := NewHub()
	count := 10000

	cs := make([]*Client, count)
	for i := 0; i < count; i++ {
		cs[i] = &Client{ID: strconv.Itoa(i)}
	}

	go func() {
		for i := 0; i < count; i++ {
			hub.Add(cs[i])
		}
	}()

	go func() {
		for i := 0; i < count; i++ {
			hub.Remove(cs[i])
		}
	}()

	go func() {
		for i := 0; i < count; i++ {
			hub.Clients()
		}
	}()
}

func TestHub_BouncesToOtherClients(t *testing.T) {
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
		env := Envelope{}
		err := json.Unmarshal(rcvMsg, &env)
		if err != nil {
			t.Fatalf("Could not unmarshal '%s': %s", rcvMsg, err.Error())
		}
		if string(env.Msg) != string(msgs[i]) {
			t.Errorf("ws2, i=%d, received '%s' but expected '%s'",
				i, env.Msg, msgs[i],
			)
		}

		// Get a message from client 3
		ws3.SetReadDeadline(time.Now().Add(time.Second))
		_, rcvMsg, rcvErr = ws3.ReadMessage()
		if rcvErr != nil {
			t.Fatalf("Read error, ws3, i=%d: %s", i, rcvErr.Error())
		}
		env = Envelope{}
		err = json.Unmarshal(rcvMsg, &env)
		if err != nil {
			t.Fatalf("Could not unmarshal '%s': %s", rcvMsg, err.Error())
		}
		if string(env.Msg) != string(msgs[i]) {
			t.Errorf("ws3, i=%d, received '%s' but expected '%s'",
				i, env.Msg, msgs[i],
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

func TestClient_BasicMessageEnvelopeIsCorrect(t *testing.T) {
	serv := newTestServer(echoHandler)
	defer serv.Close()

	// Connect 3 clients.
	// We'll want to check From, To and Time fields, as well as
	// message contents.
	// Because we have 3 clients we'll have 2 listed in the To field.

	ws1, _, err := dial(serv, "EN1")
	defer ws1.Close()
	if err != nil {
		t.Fatal(err)
	}

	ws2, _, err := dial(serv, "EN2")
	defer ws2.Close()
	if err != nil {
		t.Fatal(err)
	}

	ws3, _, err := dial(serv, "EN3")
	defer ws3.Close()
	if err != nil {
		t.Fatal(err)
	}

	// Make sure all the clients have been added to hub.
	waitForClient(hub, "EN1")
	waitForClient(hub, "EN2")
	waitForClient(hub, "EN3")

	// Send a message, then pick up the results from one of the clients

	err = ws1.WriteMessage(
		websocket.BinaryMessage, []byte("Can you read me?"),
	)
	if err != nil {
		t.Fatalf("Error writing message: %s", err.Error())
	}

	_, msg, err := ws2.ReadMessage()
	if err != nil {
		t.Fatalf("Error reading message: %s", err.Error())
	}

	env := Envelope{}
	err = json.Unmarshal(msg, &env)
	if err != nil {
		t.Fatalf(
			"Couldn't unmarshal message '%s'. Error %s",
			msg, err.Error(),
		)
	}

	// Test fields

	t.Fatal("TODO: Test fields!")
}
