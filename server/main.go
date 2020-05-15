// Copyright 2020 Nik Silver
//
// Licensed under the GPL v3.0. See file LICENCE.txt for details.

// Simple game server
package main

import (
	"fmt"
	"net/http"
	"os"
	"sync"

	"github.com/gorilla/websocket"
	"github.com/inconshreveable/log15"
)

// Global superhub that holds all the hubs
var Shub = NewSuperhub()

// A global wait group, not used in the normal course of things,
// but useful to wait on when debuggging.
var WG = sync.WaitGroup{}

func init() {
	// Output application logs
	// log.SetLvlDebugStdout()
}

func main() {
	// Set the logger -only for when the application runs, as this is in main
	Log.SetHandler(log15.StdoutHandler)

	// Handle proof of running
	http.HandleFunc("/", helloHandler)

	// Handle game requests
	http.HandleFunc("/g/", bounceHandler)

	// Handle command for cookie annulment
	http.HandleFunc("/cmd/annul-cookie", annulCookieHandler)

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
		Log.Info("Using default port", "port", port)
	}

	Log.Info("Listening", "port", port)
	if err := http.ListenAndServe(":"+port, nil); err != nil {
		Log.Crit("ListenAndServe", "error", err)
		os.Exit(1)
	}
}

// bounceHandler sets up a websocket to bounce whatever it receives to
// other clients in the same game.
func bounceHandler(w http.ResponseWriter, r *http.Request) {
	// Create a websocket connection
	clientID := ClientIDOrNew(r.Cookies())
	ws, err := Upgrade(w, r, clientID)
	if err != nil {
		Log.Warn("Upgrade", "error", err)
		return
	}

	// Make sure we can get a hub
	hub, err := Shub.Hub(r.URL.Path)
	if err != nil {
		msg := websocket.FormatCloseMessage(
			websocket.CloseNormalClosure, err.Error())
		// The following calls may error, but we're exiting, so will ignore
		ws.WriteMessage(websocket.CloseMessage, msg)
		ws.Close()
		return
	}

	// Start the client handler running
	c := &Client{
		ID:      clientID,
		WS:      ws,
		Hub:     hub,
		Pending: make(chan *Message),
	}
	c.Start()
}

// annulCookieHandler sets up a websocket, annuls the client ID cookie,
// and closes.
func annulCookieHandler(w http.ResponseWriter, r *http.Request) {
	// Create a websocket connection with an empty cookie
	ws, err := Upgrade(w, r, "")
	if err != nil {
		Log.Warn("Upgrade", "error", err)
		return
	}
	ws.Close()
}

// Just say hello
func helloHandler(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path != "/" {
		http.NotFound(w, r)
		return
	}
	fmt.Fprint(w, "Hello, there")
}
