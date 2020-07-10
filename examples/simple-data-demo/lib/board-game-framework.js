// Copyright 2020 Nik Silver
//
// Licensed under the GPL v3.0. See file LICENCE.txt for details.

// The layer from our application to the plumbing
function BoardGameFramework() {
    // This function
    var top = this;

    // Our websocket
    this._ws = null;

    // Base URL we've most recently tried to open, and which we may need to
    // reconnect to
    this._baseURL = null;

    // The URL to open next, if we try to open a connection while we've still
    // got one
    this._nextOpen = null;

    // Client ID, if known
    this._id = null;

    // Last num received
    this._num = -1;

    // Reconnection attempt counter. If we reconnect we go 3, 2, 1, 0.
    // If this is 0 it means won't try to reconnect if the connection closes.
    this._reconnCounter = 0;

    // Send an envelope of data to the main application.
    // Replace this default implementation in your app.
    this.toapp = function(env) {
        console.log("toapp(env). Replace this with your own implementation");
    };

    // Act on an instruction from the main app: Open, Close, Send
    this.act = function(data) {
        switch (data.instruction) {
            case 'Open':
                // Open a new connection, not a reconnection
                if (this._ws) {
                    // Already open, so line up the URL to be opened next,
                    // and close the current connection.
                    this._nextOpen = data.url;
                    this._reconnCounter = 0;
                    this._ws.close();
                    return;
                }
                this._num = -1;
                this._reconnCounter = 0;
                this._baseURL = data.url;
                url = this._makeConnURL(data.url);
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
    };

    // Open a websocket and set up the event handlers.
    // Opening a second websocket will close the first one.
    this.open = function(url) {
        this._ws = this._newWebSocket(url);
        console.log("open: Opened url " + url);
        this._ws.onopen = function(evt) {
            console.log("open.open: Got event");
            // We've got an open connection.
            // Future connections will be reconnection
            top._reconnCounter = 3;
        }
        this._ws.onclose = async function(evt) {
            console.log("open.onclose: Got event");
            // We got a close; should we reconnect for the main app?
            if (top._reconnCounter > 0) {
                // Need to reconnect
                url = top._makeConnURL(top._baseURL);
                await new Promise(r => setTimeout(r, top._delay()));
                --top._reconnCounter;
                top.open(url);
                return;
            }
            // We accept this close
            top.toapp({closed: true});
            top._ws = null;
            top._baseURL = null;
            if (top._nextOpen) {
                url = top._nextOpen;
                top._nextOpen = null;
                top.act({instruction: 'Open', url: url});
            }
        }
        this._ws.onmessage = function(evt) {
            console.log("open.onmessage: Got event");
            // Get the received envelope as structured data
            env = JSON.parse(evt.data);
            // If there's a body (base64 encoded) decode it
            if (env.Body) {
                env.Body = JSON.parse(atob(env.Body));
            }
            // Record the client ID and envelope num
            if (env.Intent == 'Welcome') {
                top._id = env.To[0];
            }
            if (env.Num >= 0) {
                top._num = env.Num;
            }
            top.toapp(env);
        }
        this._ws.onerror = function(evt) {
            // Error details can't be determined by design. See
            // https://stackoverflow.com/a/31003057/1830955
            // The browser will also close the websocket
            // Only pass on the error if wouldn't want to reconnect
            if (top._reconnCounter <= 0) {
                top.toapp({error: "Websocket error"});
            }
        }
    };

    // Return a new websocket connection. To be overridden in tests.
    this._newWebSocket = function(url) {
        return new WebSocket(url);
    };

    // Make a connection URL using some URL, but also what we know
    // about whether we're reconnecting and the last num received.
    this._makeConnURL = function(url) {
        var params = new URLSearchParams();
        if (this._id != null) {
            params.set('id', this._id);
        }
        if (this._reconnCounter > 0) {
            // It's a reconnection
            params.set('lastnum', this._num);
        }
        // Only add a '?' if necessary
        var query = params.toString() ? '?' : '';
        // It's a reconnection
        return url + query + params.toString();
    };

    // Calculate a delay for reconnecting. The first reconnection should
    // be immediate. Later ones should get further apart. There should
    // also be some randomness in it.
    this._delay = function() {
        switch (this._reconnCounter) {
            case 3:
                return 0;
            case 2:
                return 750 + Math.random()*500;
            case 1:
                return 1500 + Math.random()*1000;
            default:
                return 1500 + Math.random()*1000;
        }
    };

};

// Export the object if we're calling this as a module (e.g. when testing).
if (typeof exports !== 'undefined') {
    exports.BoardGameFramework = BoardGameFramework;
}
