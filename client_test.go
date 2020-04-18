package main

import (
	"log"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestCookie_CreateNew(t *testing.T) {
	req, err := http.NewRequest("GET", "/", nil)
	if err != nil {
		t.Fatal(err)
	}

	rr := httptest.NewRecorder()
	handler := http.HandlerFunc(indexHandler)
	handler.ServeHTTP(rr, req)

	if status := rr.Code; status != http.StatusOK {
		t.Errorf(
			"unexpected status: got (%v) want (%v)",
			status,
			http.StatusOK,
		)
	}

	cookies := rr.Result().Cookies()
	var clientID string
	for _, cookie := range cookies {
		if cookie.Name == "clientID" {
			clientID = cookie.Value
			log.Printf("clientID is %s", clientID)
			log.Printf("clientID string is %s", cookie.String())
		}
	}
	if clientID == "" {
		t.Errorf("clientID cookie is empty or not defined")
	}
}

func TestCookie_ReusesOld(t *testing.T) {
	req, err := http.NewRequest("GET", "/", nil)
	if err != nil {
		t.Fatal(err)
	}
	req.AddCookie(&http.Cookie{
		Name:  "clientID",
		Value: "existing value",
	})

	rr := httptest.NewRecorder()
	handler := http.HandlerFunc(indexHandler)
	handler.ServeHTTP(rr, req)

	if status := rr.Code; status != http.StatusOK {
		t.Errorf(
			"unexpected status: got (%v) want (%v)",
			status,
			http.StatusOK,
		)
	}

	cookies := rr.Result().Cookies()
	var clientID string
	for _, cookie := range cookies {
		if cookie.Name == "clientID" {
			clientID = cookie.Value
			log.Printf("clientID is %s", clientID)
			log.Printf("clientID string is %s", cookie.String())
		}
	}
	if clientID != "existing value" {
		t.Errorf("clientID cookie: expected 'expected value', got '%s'",
			clientID)
	}
}

func TestCookie_NewCookiesAreDifferent(t *testing.T) {
	usedIDs := make(map[string]bool)

	for i := 0; i < 100; i++ {
		req, err := http.NewRequest("GET", "/", nil)
		if err != nil {
			t.Fatal(err)
		}

		rr := httptest.NewRecorder()
		handler := http.HandlerFunc(indexHandler)
		handler.ServeHTTP(rr, req)

		if status := rr.Code; status != http.StatusOK {
			t.Errorf(
				"unexpected status: got (%v) want (%v)",
				status,
				http.StatusOK,
			)
		}

		cookies := rr.Result().Cookies()
		var clientID string
		for _, cookie := range cookies {
			if cookie.Name == "clientID" {
				clientID = cookie.Value
				if usedIDs[clientID] {
					t.Errorf("Iteration i = %d, clientID '%s' already used",
						i,
						clientID)
				}
				usedIDs[clientID] = true
			}
		}
		if clientID == "" {
			t.Errorf("clientID not set")
		}
	}

}
