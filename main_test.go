// Copyright 2020 Nik Silver
//
// Licensed under the GPL v3.0. See file LICENCE.txt for details.

package main

import (
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

// wsServer starts a websocket server with the given handler. It returns
// a websocket Connection, the function to close the servers it started,
// and any error encountered.
func wsServer(hdlr http.HandlerFunc) (ws *websocket.Conn, closeFunc func(), err error) {
	serv := httptest.NewServer(http.HandlerFunc(hdlr))

	// Convert http://a.b.c.d to ws://a.b.c.d
	url := "ws" + strings.TrimPrefix(serv.URL, "http")

	// Connect to the server

	ws, _, wsErr := websocket.DefaultDialer.Dial(url, nil)

	clFunc := func() {
		ws.Close()
		serv.Close()
	}

	return ws, clFunc, wsErr
}

func TestEchoHandler(t *testing.T) {
	ws, cf, err := wsServer(echoHandler)
	defer cf()
	if err != nil {
		t.Fatal(err)
	}

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
