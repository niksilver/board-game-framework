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

    // Send an envelope of data to the main application.
    // Replace this default implementation in your app.
    toapp: function(env) {
        console.log("toapp(env). Replace this with your own implementation");
    },

    // Act on an instruction from the main app: Open, Close, Send
    act: function(data) {
        switch (data.instruction) {
            case 'Open':
                if (this._ws) {
                    // Already open, so line up the URL to be opened next,
                    // and close the current connection.
                    this._nextOpen = data.url;
                    this._ws.close();
                    return;
                }
                this.open(data.url);
                console.log("opened ws for " + data.url);
                return;
            case 'Close':
                if (!this._ws) {
                    // Closing non-existent websocket. Odd, but okay
                    return;
                }
                this._ws.close();
                return;
            case 'Send':
                if (!this._ws) {
                    this.toapp({error: "Send: Websocket not configured"});
                    return;
                }
                console.log("ws: " + this._ws);
                console.log("data: " + data);
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
            // No action
        }
        this._ws.onclose = function(evt) {
            parent.toapp({close: true});
            parent._ws = null;
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
            parent.toapp({error: "Websocket error"});
        }
    },

};
