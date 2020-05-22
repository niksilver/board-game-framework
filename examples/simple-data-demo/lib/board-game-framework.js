// Copyright 2020 Nik Silver
//
// Licensed under the GPL v3.0. See file LICENCE.txt for details.

// The layer from our application to the plumbing
var boardgameframework = {
    // Our websocket
    ws: null,

    // Send an envelope of data to the main application.
    // Replace this default implementation in your app.
    toapp: function(env) {
        console.log("toapp(env). Replace this with your own implementation");
    },

    // Act on an instruction from the main app: Open, Close, Send
    act: function(data) {
        switch (data.instruction) {
            case 'Open':
                this.open(data.url);
                return;
            case 'Close':
                if (!this.ws) {
                    // Closing non-existent websocket. Odd, but okay
                    return;
                }
                this.ws.close();
                return;
            case 'Send':
                if (!this.ws) {
                    this.toapp({error: "Send: Websocket not configured"});
                    return;
                }
                this.ws.send(JSON.stringify(data.body));
                return;
            default:
                this.toapp({error: "Unrecognised instruction"});
                return;
        }
    },

    // Open a websocket and set up the event handlers
    open: function(url) {
        parent = this;
        this.ws = new WebSocket(url);
        this.ws.onopen = function(evt) {
            // No action
        }
        this.ws.onclose = function(evt) {
            parent.toapp({close: true});
            parent.ws = null;
        }
        this.ws.onmessage = function(evt) {
            // Get the received envelope as structured data
            env = JSON.parse(evt.data);
            // If there's a body (base64 encoded) decode it
            if (env.Body) {
                env.Body = JSON.parse(atob(env.Body));
            }
            parent.toapp(env);
        }
        this.ws.onerror = function(evt) {
            // Error details can't be determined by design. See
            // https://stackoverflow.com/a/31003057/1830955
            // The browser will also close the websocket
            parent.toapp({error: "Websocket error"});
        }
    },

};
