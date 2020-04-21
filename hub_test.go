package main

import (
	"sort"
	"testing"
)

func TestHubAdd_CanAddAndGetClients(t *testing.T) {
	hub := NewHub()

	// A new Hub should have no clients
	len0 := len(hub.Clients())
	if len0 != 0 {
		t.Fatalf("New hub had %d clients but expected none", len0)
	}

	// Add one client and check the hub has only one client
	id1 := "id1"
	hub.Add(&Client{ID: id1})
	cl1 := hub.Clients()
	act1 := len(cl1)
	if act1 != 1 {
		t.Fatalf(
			"Client 1: Hub had %d clients but expected 1: %#v",
			act1,
			cl1,
		)
	}
	if cl1[0].ID != id1 {
		t.Fatalf(
			"Client 1: Hub's first client id was '%s' but expected '%s'",
			cl1[0].ID,
			id1,
		)
	}

	// Add a second client and check the hub has two clients
	id2 := "id2"
	hub.Add(&Client{ID: id2})
	cl2 := hub.Clients()
	act2 := len(cl2)
	if act2 != 2 {
		t.Fatalf("Client 2: Hub had %d clients but expected 2", act2)
	}

	// Check the two clients are what we expect them to be
	sort.Slice(cl2, func(i int, j int) bool { return cl2[i].ID < cl2[j].ID })
	if cl2[0].ID != id1 {
		t.Errorf(
			"Client 2: Hub's first client id was '%s' but expected '%s'",
			cl2[0].ID,
			id1,
		)
	}
	if cl2[1].ID != id2 {
		t.Errorf(
			"Client 2: Hub's second client id was '%s' but expected '%s'",
			cl2[1].ID,
			id2,
		)
	}
}
