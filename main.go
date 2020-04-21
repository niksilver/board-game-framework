// Copyright 2020 Nik Silver
//
// Licensed under the GPL v3.0. See file LICENCE.txt for details.

// Simple game server
package main

import (
	"log"
	"net/http"
	"os"
)

func main() {
	http.HandleFunc("/", echoHandler)

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
		log.Printf("Defaulting to port %s", port)
	}

	log.Printf("Listening on port %s", port)
	if err := http.ListenAndServe(":"+port, nil); err != nil {
		log.Fatal(err)
	}
}

// echoHandler sets up a websocket to echo whatever it receives
func echoHandler(w http.ResponseWriter, r *http.Request) {
	// log.Print("Got connection request")
	if r.URL.Path != "/" {
		http.NotFound(w, r)
		return
	}

	// Create a websocket connection, and a client for it
	clientID := ClientID(r.Cookies())
	ws, err := Upgrade(w, r, clientID)
	if err != nil {
		log.Print("Upgrade error: ", err)
		return
	}
	defer ws.Close()

	// Forever echo messages
	for {
		mType, msg, err := ws.ReadMessage()
		if err != nil {
			log.Print("Read message error: ", err)
			break
		}
		// Currently ignores message type
		err = ws.WriteMessage(mType, msg)
		if err != nil {
			log.Print("Write message error: ", err)
			break
		}
	}
}
