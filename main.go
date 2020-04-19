// Copyright 2020 Nik Silver
//
// Licensed under the GPL v3.0. See file LICENCE.txt for details.

// Simple game server
package main

import (
	"log"
	"net/http"
	"os"

	"github.com/gorilla/websocket"
)

var upgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool {
		// If set, the Origin host is in r.Header["Origin"][0])
		// The request host is in r.Host
		// We won't worry about the origin, to help with testing locally
		return true
	},
}

func main() {
	http.HandleFunc("/", echoHandler)

	// [START setting_port]
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
		log.Printf("Defaulting to port %s", port)
	}

	log.Printf("Listening on port %s", port)
	if err := http.ListenAndServe(":"+port, nil); err != nil {
		log.Fatal(err)
	}
	// [END setting_port]
}

// echoHandler sets up a websocket to echo whatever it receives
func echoHandler(w http.ResponseWriter, r *http.Request) {
	log.Print("Got connection request")
	if r.URL.Path != "/" {
		http.NotFound(w, r)
		return
	}

	// Set the client ID, and give it a max age of 100 years from now
	c := NewClient(r)
	cookie := &http.Cookie{
		Name:   "clientID",
		Value:  c.id,
		MaxAge: 60 * 60 * 24 * 365 * 100,
	}
	cookieStr := cookie.String()
	header := http.Header(make(map[string][]string))
	header.Add("Set-Cookie", cookieStr)

	conn, err := upgrader.Upgrade(w, r, header)
	if err != nil {
		log.Print("Upgrade error: ", err)
		return
	}
	defer conn.Close()

	for {
		mType, msg, err := conn.ReadMessage()
		if err != nil {
			log.Print("Read message error: ", err)
			break
		}
		// Currently ignores message type
		err = conn.WriteMessage(mType, msg)
		if err != nil {
			log.Print("Write message error: ", err)
			break
		}
	}
}
