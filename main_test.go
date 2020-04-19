// Copyright 2020 Nik Silver
//
// Licensed under the GPL v3.0. See file LICENCE.txt for details.

package main

import (
	"testing"

	"github.com/gorilla/websocket"
)

func TestEchoHandler(t *testing.T) {
	ws, _, cf, err := wsServerConn(echoHandler)
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
