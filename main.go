// Copyright 2020 Nik Silver
//
// Licensed under the GPL v3.0. See file LICENCE.txt for details.

// Simple game server
package main

import (
	"net/http"
	"os"

	log "github.com/inconshreveable/log15"
)

var logger = log.New()

func init() {
	handler := log.LvlFilterHandler(log.LvlCrit, log.StreamHandler(os.Stdout, log.LogfmtFormat()))
	logger.SetHandler(handler)
}

func main() {
	http.HandleFunc("/", echoHandler)

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
		logger.Info("Using default port", "port", port)
	}

	logger.Info("Listening", "port", port)
	if err := http.ListenAndServe(":"+port, nil); err != nil {
		logger.Crit("ListenAndServe", "error", err)
		os.Exit(1)
	}
}

// echoHandler sets up a websocket to echo whatever it receives
func echoHandler(w http.ResponseWriter, r *http.Request) {
	logger.Debug("Got connection request")
	if r.URL.Path != "/" {
		http.NotFound(w, r)
		return
	}

	// Create a websocket connection, and a client for it
	clientID := ClientID(r.Cookies())
	ws, err := Upgrade(w, r, clientID)
	if err != nil {
		logger.Warn("Upgrade", "error", err)
		return
	}
	c := &Client{
		ID:        clientID,
		Websocket: ws,
	}
	c.Run()
}
