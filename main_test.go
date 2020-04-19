// Copyright 2020 Nik Silver
//
// Licensed under the GPL v3.0. See file LICENCE.txt for details.

package main

import (
	"log"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/gorilla/websocket"
)

func TestIndexHandler(t *testing.T) {
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

	expected := "Hello, World!"
	if rr.Body.String() != expected {
		t.Errorf(
			"unexpected body: got (%v) want (%v)",
			rr.Body.String(),
			expected,
		)
	}
}

func TestEchoHandler(t *testing.T) {
	serv := httptest.NewServer(http.HandlerFunc(echoHandler))
	defer serv.Close()

	// Convert http://a.b.c.d to ws://a.b.c.d
	url := "ws" + strings.TrimPrefix(serv.URL, "http")
	log.Print("Converted URL is ", url)

	// Connect to the server

	ws, _, err := websocket.DefaultDialer.Dial(url, nil)
	if err != nil {
		t.Fatal(err)
	}
	defer ws.Close()

	msg := []byte("Testing, testing")
	if err := ws.WriteMessage(websocket.BinaryMessage, msg); err != nil {
		t.Fatal("Write error: ", err)
	}
	_, rcvMsg, rcvErr := ws.ReadMessage()
	if rcvErr != nil {
		t.Fatal("Read error: ", err)
	}
	if string(rcvMsg) != string(msg) {
		t.Errorf("Received '%s' but expected '%s'", rcvMsg, msg)
	}
}

func TestIndexHandlerNotFound(t *testing.T) {
	req, err := http.NewRequest("GET", "/404", nil)
	if err != nil {
		t.Fatal(err)
	}

	rr := httptest.NewRecorder()
	handler := http.HandlerFunc(indexHandler)
	handler.ServeHTTP(rr, req)

	if status := rr.Code; status != http.StatusNotFound {
		t.Errorf(
			"unexpected status: got (%v) want (%v)",
			status,
			http.StatusNotFound,
		)
	}
}
