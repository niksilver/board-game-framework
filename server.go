// Copyright 2020 Nik Silver
//
// Licensed under the GPL v3.0. See file LICENCE.txt for details.

// Simple game server
package main

import (
	"fmt"
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

// indexHandler responds to requests with our greeting.
func indexHandler(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path != "/" {
		http.NotFound(w, r)
		return
	}

	c := NewClient(r)
	http.SetCookie(w, &http.Cookie{
		Name:  "clientID",
		Value: c.id,
	})
	fmt.Fprint(w, "Hello, World!")
}

// echoHandler sets up a websocket to echo whatever it receives
func echoHandler(w http.ResponseWriter, r *http.Request) {
	log.Print("Got request")
	if r.URL.Path != "/" {
		http.NotFound(w, r)
		return
	}

	c := NewClient(r)
	http.SetCookie(w, &http.Cookie{
		Name:  "clientID",
		Value: c.id,
	})

	conn, err := upgrader.Upgrade(w, r, nil)
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
