// Copyright 2020 Nik Silver
//
// Licensed under the GPL v3.0. See file LICENCE.txt for details.

package main

import (
	"math/rand"
	"strconv"
	"sync"
	"testing"
	"time"

	"github.com/gorilla/websocket"
)

// A test for general connecting, disconnecting and message sending,
// but ensuring the superhub removes all clients.
// This just needs to run and not deadlock.
func TestSuperhub_LotsOfActivityEndsWithEmptySuperHub(t *testing.T) {
	rand.Seed(time.Now().UnixNano())
	cMap := make(map[string]*websocket.Conn)
	cSlice := make([]string, 0)
	consumed := 0

	// Start a web server
	serv := newTestServer(bounceHandler)
	defer serv.Close()

	// A client should consume messages until done
	w := sync.WaitGroup{}
	consume := func(ws *websocket.Conn, id string) {
		defer w.Done()
		for {
			_, _, err := ws.ReadMessage()
			if err == nil {
				consumed += 1
			} else {
				break
			}
		}
		ws.Close()
	}

	for i := 0; i < 1000; i++ {
		action := rand.Float32()
		cCount := len(cSlice)
		switch {
		case i < 10 || action < 0.25:
			// New client join
			id := "SHUB" + strconv.Itoa(i)
			game := "/game" + strconv.Itoa(rand.Intn(10))
			ws, _, err := dial(serv, game, id)
			defer func() {
				ws.Close()
			}()
			if err != nil {
				t.Fatalf("Couldn't dial, i=%d, error '%s'", i, err.Error())
			}
			cMap[id] = ws
			cSlice = append(cSlice, id)
			w.Add(1)
			go consume(ws, id)
		case cCount > 0 && action <= 0.25 && action < 0.35:
			// Some client leaves
			idx := rand.Intn(len(cSlice))
			id := cSlice[idx]
			ws := cMap[id]
			ws.Close()
			delete(cMap, id)
			cSlice = append(cSlice[:idx], cSlice[idx+1:]...)
		case cCount > 0:
			// Some client sends a message
			idx := rand.Intn(len(cSlice))
			id := cSlice[idx]
			ws := cMap[id]
			msg := "Message " + strconv.Itoa(i)
			err := ws.WriteMessage(websocket.BinaryMessage, []byte(msg))
			if err != nil {
				t.Fatalf(
					"Couldn't write message, i=%d, id=%s error '%s'",
					i, id, err.Error(),
				)
			}
		default:
			// Can't take any action
		}
	}

	// Close remaining clients
	for _, ws := range cMap {
		ws.Close()
	}

	w.Wait()

	// Tidy up, and check everything in the main app finishes
	WG.Wait()

	if count := Shub.Count(); count != 0 {
		t.Errorf("Expected no hubs in superhub, got %d", count)
	}
}
