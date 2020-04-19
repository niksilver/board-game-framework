// Copyright 2020 Nik Silver
//
// Licensed under the GPL v3.0. See file LICENCE.txt for details.

package main

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestClient_CreatesNewID(t *testing.T) {
	req, err := http.NewRequest("GET", "/", nil)
	if err != nil {
		t.Fatal(err)
	}

	rr := httptest.NewRecorder()
	handler := http.HandlerFunc(indexHandler)
	handler.ServeHTTP(rr, req)

	if status := rr.Code; status != http.StatusOK {
		t.Errorf(
			"unexpected status: got (%v) want (%v)",
			status,
			http.StatusOK,
		)
	}

	cookies := rr.Result().Cookies()
	clientID := clientID(cookies)
	if clientID == "" {
		t.Errorf("clientID cookie is empty or not defined")
	}
}

func TestWSClient_CreatesNewID(t *testing.T) {
	_, resp, closeFunc, err := wsServerConn(echoHandler)
	defer closeFunc()
	if err != nil {
		t.Fatal(err)
	}

	cookies := resp.Cookies()
	clientID := clientID(cookies)
	if clientID == "" {
		t.Errorf("clientID cookie is empty or not defined")
	}
}

func TestClient_ReusesOldID(t *testing.T) {
	req, err := http.NewRequest("GET", "/", nil)
	if err != nil {
		t.Fatal(err)
	}
	req.AddCookie(&http.Cookie{
		Name:  "clientID",
		Value: "existing value",
	})

	rr := httptest.NewRecorder()
	handler := http.HandlerFunc(indexHandler)
	handler.ServeHTTP(rr, req)

	if status := rr.Code; status != http.StatusOK {
		t.Errorf(
			"unexpected status: got (%v) want (%v)",
			status,
			http.StatusOK,
		)
	}

	cookies := rr.Result().Cookies()
	clientID := clientID(cookies)
	if clientID != "existing value" {
		t.Errorf("clientID cookie: expected 'expected value', got '%s'",
			clientID)
	}
}

func TestWSClient_ReusesOldId(t *testing.T) {
	cookieValue := "existing value"

	_, resp, closeFunc, err := wsServerConnWithCookie(
		echoHandler, "clientID", cookieValue)
	defer closeFunc()
	if err != nil {
		t.Fatal(err)
	}

	cookies := resp.Cookies()
	clientID := clientID(cookies)
	if clientID != cookieValue {
		t.Errorf("clientID cookie: expected '%s', got '%s'",
			clientID,
			cookieValue)
	}
}

func TestClient_NewIDsAreDifferent(t *testing.T) {
	usedIDs := make(map[string]bool)

	for i := 0; i < 100; i++ {
		req, err := http.NewRequest("GET", "/", nil)
		if err != nil {
			t.Fatal(err)
		}

		rr := httptest.NewRecorder()
		handler := http.HandlerFunc(indexHandler)
		handler.ServeHTTP(rr, req)

		if status := rr.Code; status != http.StatusOK {
			t.Errorf(
				"unexpected status: got (%v) want (%v)",
				status,
				http.StatusOK,
			)
		}

		cookies := rr.Result().Cookies()
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

func TestWSClient_NewIDsAreDifferent(t *testing.T) {
	usedIDs := make(map[string]bool)

	for i := 0; i < 100; i++ {
		// Get a new client/server connection
		_, resp, closeFunc, err := wsServerConn(echoHandler)
		defer closeFunc()
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
		closeFunc()
	}

}
