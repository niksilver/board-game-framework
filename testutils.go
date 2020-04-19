package main

import (
	"net/http"
	"net/http/httptest"
	"strings"

	"github.com/gorilla/websocket"
)

// wsServerConnWithCookie starts a websocket server with the given handler,
// plus a connection which send an initial cookie (with name and value).
// It returns the websocket.Connection, the http response,
// the function to close the servers it started,
// and any error encountered.
func wsServerConnWithCookie(hdlr http.HandlerFunc, name string, value string) (
	ws *websocket.Conn,
	resp *http.Response,
	closeFunc func(),
	err error,
) {
	serv := httptest.NewServer(http.HandlerFunc(hdlr))

	// Convert http://a.b.c.d to ws://a.b.c.d
	url := "ws" + strings.TrimPrefix(serv.URL, "http")

	// If necessary, creater a header with the given cookie
	var header http.Header
	if name != "" {
		header = cookieRequestHeader(name, value)
	}

	// Connect to the server

	ws, resp, wsErr := websocket.DefaultDialer.Dial(url, header)

	closeFunc = func() {
		ws.Close()
		serv.Close()
	}

	return ws, resp, closeFunc, wsErr
}

// wsServerConn starts a websocket server with the given handler, plus a
// connection.
// It returns the websocket.Connection, the http response,
// the function to close the servers it started,
// and any error encountered.
func wsServerConn(hdlr http.HandlerFunc) (
	ws *websocket.Conn,
	resp *http.Response,
	closeFunc func(),
	err error,
) {
	return wsServerConnWithCookie(hdlr, "", "")
}

// cookieHeader returns an http.Header for a client request,
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
