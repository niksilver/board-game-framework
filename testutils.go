package main

import (
	"net/http"
	"net/http/httptest"
	"strings"

	"github.com/gorilla/websocket"
)

// newTestServer creates a new server to connect to, using the given handler.
func newTestServer(hdlr http.HandlerFunc) *httptest.Server {
	return httptest.NewServer(http.HandlerFunc(hdlr))
}

// dial connects to a test server, sending a clientID (if non-empty).
func dial(serv *httptest.Server, clientID string) (
	ws *websocket.Conn,
	resp *http.Response,
	err error,
) {
	// Convert http://a.b.c.d to ws://a.b.c.d
	url := "ws" + strings.TrimPrefix(serv.URL, "http")

	// If necessary, creater a header with the given cookie
	var header http.Header
	if clientID != "" {
		header = cookieRequestHeader("clientID", clientID)
	}

	// Connect to the server

	return websocket.DefaultDialer.Dial(url, header)
}

// cookieRequestHeader returns a new http.Header for a client request,
// in which only a single cookie is sent, with some value.
func cookieRequestHeader(name string, value string) http.Header {
	cookie := &http.Cookie{
		Name:  name,
		Value: value,
	}
	cookieStr := cookie.String()
	header := http.Header(make(map[string][]string))
	header.Add("Cookie", cookieStr)

	return header
}
