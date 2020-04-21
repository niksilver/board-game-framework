// Copyright 2020 Nik Silver
//
// Licensed under the GPL v3.0. See file LICENCE.txt for details.

package main

// Hub collects all related clients
type Hub struct {
	clients map[*Client]bool
}

// NewHub creates a new, empty Hub.
func NewHub() *Hub {
	return &Hub{
		clients: make(map[*Client]bool),
	}
}

// Add adds a new Client into the Hub.
func (h *Hub) Add(c *Client) {
	h.clients[c] = true
}

// Clients returns a slice with all the Hub's Clients.
func (h *Hub) Clients() []*Client {
	cs := make([]*Client, 0, len(h.clients))
	for c := range h.clients {
		cs = append(cs, c)
	}

	return cs
}
