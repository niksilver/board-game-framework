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

	// Create a websocket connection, and a client for it
	clientID := ClientIDOrNew(r.Cookies())
	ws, err := Upgrade(w, r, clientID)
	if err != nil {
		log.Log.Warn("Upgrade", "error", err)
		return
	}

	// Make sure we can get a hub
	hub, err := shub.Hub(r.URL.Path)
	tLog.Debug("main, got hub", "id", clientID, "hub", hub, "err", err)
	if err != nil {
		tLog.Debug("main, got hub error", "id", clientID, "err", err)
		msg := websocket.FormatCloseMessage(
			websocket.CloseNormalClosure, err.Error())
		if err := ws.WriteMessage(websocket.CloseMessage, msg); err != nil {
			tLog.Debug("main, got write error", "id", clientID, "err", err)
			// Ignore write error, we're exiting anyway
		}
		if err := ws.Close(); err != nil {
			tLog.Debug("main, got close error", "id", clientID, "err", err)
		}
		//w.WriteHeader(http.StatusServiceUnavailable)
		//w.Write([]byte(err.Error()))
		return
	}
	c := &Client{
		ID:      clientID,
		WS:      ws,
		Hub:     hub,
		Pending: make(chan *Message),
	}
	c.Start()
}
