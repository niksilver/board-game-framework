// Copyright 2020 Nik Silver
//
// Licensed under the GPL v3.0. See file LICENCE.txt for details.

// Simple game server
package main

import (
	"net/http"
	"os"
	"sync"

	"github.com/gorilla/websocket"
	"github.com/inconshreveable/log15"
	"github.com/niksilver/board-game-framework/log"
)

// Global superhub that holds all the hubs
var shub = NewSuperhub()

// A global wait group, not used in the normal course of things,
// but useful to wait on when debuggging.
var wg = sync.WaitGroup{}

func init() {
	// Output application logs
	// log.SetLvlDebugStdout()
}

func main() {
	// Set the logger -only for when the application runs, as this is in main
	log.Log.SetHandler(log15.StdoutHandler)

	http.HandleFunc("/", bounceHandler)

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
		log.Log.Info("Using default port", "port", port)
	}

	log.Log.Info("Listening", "port", port)
	if err := http.ListenAndServe(":"+port, nil); err != nil {
		log.Log.Crit("ListenAndServe", "error", err)
		os.Exit(1)
	}
}

// bounceHandler sets up a websocket to bounce whatever it receives to
// other clients in the same game.
func bounceHandler(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path == "" || r.URL.Path == "/" {
		http.NotFound(w, r)
		return
	}

	// Create a websocket connection
	clientID := ClientIDOrNew(r.Cookies())
	ws, err := Upgrade(w, r, clientID)
	if err != nil {
		log.Log.Warn("Upgrade", "error", err)
		return
	}

	// Make sure we can get a hub
	hub, err := shub.Hub(r.URL.Path)
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
