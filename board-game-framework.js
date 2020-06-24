// Copyright 2020 Nik Silver
//
// Licensed under the GPL v3.0. See file LICENCE.txt for details.

// The layer from our application to the plumbing
var boardgameframework = {
    // Our websocket
    _ws: null,

    // The URL to open next, if we try to open a connection while we've still
    // got one
    _nextOpen : null,

    // Last num received
    _num : -1,

    // Reconnection attempt counter. If we reconnect we go 3, 2, 1, 0.
    // If this is 0 it means we are trying a new connection, not a
    // reconnection.
    _reconnCounter: 0,

    // Are we currently trying to reconnect?
    _reconnecting: false,

    // Send an envelope of data to the main application.
    // Replace this default implementation in your app.
    toapp: function(env) {
        console.log("toapp(env). Replace this with your own implementation");
    },

    // Act on an instruction from the main app: Open, Close, Send
    act: function(data) {
        switch (data.instruction) {
            case 'Open':
                // Open a new connection, not a reconnection
                if (this._ws) {
                    // Already open, so line up the URL to be opened next,
                    // and close the current connection.
                    this._nextOpen = data.url;
                    this._ws.close();
                    return;
                }
                this._num = -1;
                this._reconnCounter = 0;
                this._reconnecting = false;
                url = this.makeConnURL(data.url)
                console.log("Opening url=" + url + ", _reconnCounter=" + this._reconnCounter);
                this.open(url);
                return;
            case 'Close':
                if (!this._ws) {
                    // Closing non-existent websocket. Odd, but okay
                    return;
                }
                // This is a requested close, so we don't want to
                // reconnect
                this._reconnCounter = 0;
                this._reconnecting = false;
                this._ws.close();
                return;
            case 'Send':
                if (!this._ws) {
                    this.toapp({error: "Send: Websocket not configured"});
                    return;
                }
                this._ws.send(JSON.stringify(data.body));
                return;
            default:
                this.toapp({error: "Unrecognised instruction"});
                return;
        }
    },

    // Open a websocket and set up the event handlers.
    // Opening a second websocket will close the first one.
    open: function(url) {
        parent = this;
        this._ws = new WebSocket(url);
        this._ws.onopen = function(evt) {
            // We've got an open connection.
            // Future connections will be reconnection
            parent._reconnCounter = 3;
            parent._reconnecting = false;
            console.log("Got onopen, _reconnCounter reset to 3");
        }
        this._ws.onclose = function(evt) {
            // We got a close; should we reconnect for the main app?
            if (parent._reconnCounter > 0) {
                // Need to reconnect
                parent.makeConnURL(this._ws);
                parent._reconnCounter--;
                parent._reconnecting = true;
                console.log("Reopening url=" + url + ", _reconnCounter=" + parent._reconnCounter);
                parent.open(url);
                return;
            }
            // We accept this close
            parent.toapp({closed: true});
            parent._ws = null;
            parent._reconnecting = false;
            if (parent._nextOpen) {
                url = parent._nextOpen;
                parent._nextOpen = null;
                parent.act({instruction: 'Open', url: url});
            }
        }
        this._ws.onmessage = function(evt) {
            // Get the received envelope as structured data
            env = JSON.parse(evt.data);
            // If there's a body (base64 encoded) decode it
            if (env.Body) {
                env.Body = JSON.parse(atob(env.Body));
            }
            parent.toapp(env);
        }
        this._ws.onerror = function(evt) {
            // Error details can't be determined by design. See
            // https://stackoverflow.com/a/31003057/1830955
            // The browser will also close the websocket
            // Don't pass on the error if we're trying to reconnect
            if (!parent._reconnecting) {
                parent.toapp({error: "Websocket error"});
            }
        }
    },

    // Make a connection URL using some URL, but also what we know
    // about whether we're reconnecting and the last num received.
    makeConnURL: function(url) {
        if (this._reconnCounter >= 0) {
            // New connection
            return url;
        }
        // It's a reconnection
        return url + "?lastnum=" + this._num;
    }

};
