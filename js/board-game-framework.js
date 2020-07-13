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
    // reconnect to.
    // As long as this is not null it tells us we should attempt to
    // reconnect after a connection close.
    this._baseURL = null;

    // The URL to open next, if we try to open a connection while we've still
    // got one
    this._nextOpen = null;

    // Client ID, if known
    this._id = null;

    // Last num received. -1 means there was no last num received.
    this._num = -1;

    // True if we're in the middle of reconnecting
    this._reconnecting = false;

    // A timeout ID for a function that fires when the timeout is stable;
    // possibly null.
    this._stableTimeoutID = null;

    // How long a connection needs to be stable for us to say
    // we're connected (in milliseconds).
    this._stablePeriod = 2000;

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
                    this._baseURL = null;
                    this._ws.close();
                    return;
                }
                this._num = -1;
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
                this._baseURL = null;
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
            // We've got an open connection
            console.log("open.onopen: Got event");
            // Take action when this connection is deemed stable
            top._stableTimeoutID =
                setTimeout(function() {
                    console.log('open.onopen.setTimeout: fired');
                    top._reconnecting = true;
                    top.toapp({opened: true});
                }, top._stablePeriod);
        }

        this._ws.onclose = async function(evt) {
            // We've got an close connection.
            console.log("open.onclose: Got event");
            // Can't claim we've got a stable connection
            clearTimeout(top._stableTimeoutID);
            // Reset the lastnum if we've been told it's bad
            if (evt.code == 4000 ||
                (typeof evt.reason == 'string' &&
                    evt.reason.includes('lastnum'))) {
                top._num = -1;
            }
            // We got a close; should we reconnect for the main app?
            if (top._baseURL != null) {
                // Need to reconnect
                console.log('open.onclose: Need to reconnect');
                // Tell the app we're reconnecting if it's our first time
                if (!top._reconnecting) {
                    top.toapp({reconnecting: true});
                    top._reconnecting = true;
                }
                url = top._makeConnURL(top._baseURL);
                await new Promise(r => setTimeout(r, top._delay()));
                top.open(url);
                return;
            }
            // We accept this close
            top.toapp({closed: true});
            top._ws = null;
            top._baseURL = null;
            top._num = -1;
            // Open the next connection if there is one
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
            // REMOVE THIS - IT'S JUST HERE FOR TESTING!
            for (const [key, value] of Object.entries(evt)) {
                console.log("open.onerror: " + key + "=" + value);
            }
            // Error details can't be determined by design. See
            // https://stackoverflow.com/a/31003057/1830955
            // The browser will also close the websocket
            // Only pass on the error if wouldn't want to reconnect
            if (top._baseURL == null) {
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
        if (this._baseURL != null && this._num >= 0) {
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
        return 750 + Math.random()*500;
    };

};

// Export the object if we're calling this as a module (e.g. when testing).
if (typeof exports !== 'undefined') {
    exports.BoardGameFramework = BoardGameFramework;
}
