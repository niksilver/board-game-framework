// Copyright 2020 Nik Silver
//
// Licensed under the GPL v3.0. See file LICENCE.txt for details.

// Simple game server
package main

import (
	"net/http"
	"os"

	"github.com/inconshreveable/log15"
	"github.com/niksilver/board-game-framework/log"
)

func main() {
	// Set the logger -only for when the application runs, as this is in main
	log.Log.SetHandler(log15.StdoutHandler)

	http.HandleFunc("/", echoHandler)

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

// echoHandler sets up a websocket to echo whatever it receives
func echoHandler(w http.ResponseWriter, r *http.Request) {
	log.Log.Debug("Got connection request")
	if r.URL.Path != "/" {
		http.NotFound(w, r)
		return
	}

	// Create a websocket connection, and a client for it
	clientID := ClientID(r.Cookies())
	ws, err := Upgrade(w, r, clientID)
	if err != nil {
		log.Log.Warn("Upgrade", "error", err)
		return
	}
	c := &Client{
		ID:        clientID,
		Websocket: ws,
	}
	c.Run()
}
