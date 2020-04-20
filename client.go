// Copyright 2020 Nik Silver
//
// Licensed under the GPL v3.0. See file LICENCE.txt for details.

package main

import (
	"fmt"
	"math/rand"
	"net/http"
	"time"
)

type Client struct {
	ID string
}

// NewClient creates a new client proxy from an incoming request
func NewClient(r *http.Request) Client {
	clientID := clientID(r.Cookies())
	if clientID == "" {
		clientID = newClientID()
	}

	return Client{
		ID: clientID,
	}
}

// newClientID generates a random clientID string
func newClientID() string {
	return fmt.Sprintf(
		"%d.%d",
		time.Now().Unix(),
		rand.Int31(),
	)
}

// clientID returns the value of the clientID cookie, or empty string
// if there's none there
func clientID(cookies []*http.Cookie) string {
	for _, cookie := range cookies {
		if cookie.Name == "clientID" {
			return cookie.Value
		}
	}

	return ""
}

// clientID returns the Max-Age value of the clientID cookie,
// or 0 if there's none there
func clientIDMaxAge(cookies []*http.Cookie) int {
	for _, cookie := range cookies {
		if cookie.Name == "clientID" {
			return cookie.MaxAge
		}
	}

	return 0
}
