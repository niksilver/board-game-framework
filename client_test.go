// Copyright 2020 Nik Silver
//
// Licensed under the GPL v3.0. See file LICENCE.txt for details.

package main

import (
	"testing"
)

func TestWSClient_CreatesNewID(t *testing.T) {
	serv := newTestServer(echoHandler)
	defer serv.Close()

	ws, resp, err := dial(serv, "")
	defer ws.Close()
	if err != nil {
		t.Fatal(err)
	}

	cookies := resp.Cookies()
	clientID := clientID(cookies)
	if clientID == "" {
		t.Errorf("clientID cookie is empty or not defined")
	}
}

func TestWSClient_ClientIDCookieIsPersistent(t *testing.T) {
	serv := newTestServer(echoHandler)
	defer serv.Close()

	ws, resp, err := dial(serv, "")
	defer ws.Close()
	if err != nil {
		t.Fatal(err)
	}

	cookies := resp.Cookies()
	maxAge := clientIDMaxAge(cookies)
	if maxAge < 100_000 {
		t.Errorf(
			"clientID cookie has max age %d, but expected 100,000 or more",
			maxAge,
		)
	}
}

func TestWSClient_ReusesOldId(t *testing.T) {
	serv := newTestServer(echoHandler)
	defer serv.Close()

	initialClientID := "existing_value"

	ws, resp, err := dial(serv, initialClientID)
	defer ws.Close()
	if err != nil {
		t.Fatal(err)
	}

	cookies := resp.Cookies()
	clientID := clientID(cookies)
	if clientID != initialClientID {
		t.Errorf("clientID cookie: expected '%s', got '%s'",
			clientID,
			initialClientID)
	}
}

func TestWSClient_NewIDsAreDifferent(t *testing.T) {
	usedIDs := make(map[string]bool)

	for i := 0; i < 100; i++ {
		// Get a new client/server connection
		serv := newTestServer(echoHandler)
		defer serv.Close()

		ws, resp, err := dial(serv, "")
		defer ws.Close()
		if err != nil {
			t.Fatal(err)
		}

		cookies := resp.Cookies()
		clientID := clientID(cookies)

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
