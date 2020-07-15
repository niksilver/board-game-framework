// Copyright 2020 Nik Silver
//
// Licensed under the GPL v3.0. See file LICENCE.txt for details.

// The layer from our application to the plumbing
function BoardGameFramework() {
    // Send an envelope of data to the main application.
    // Replace this default implementation in your app.
    this.toApp = function(env) {
        console.log("toApp(env). Replace this with your own implementation");
    };

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

    // The string in the last connection envelope we've sent:
    // opened, connecting, or closed.
    this._lastConnEnv = null;

    // A timeout ID for a function that fires when the timeout is stable;
    // possibly null.
    this._stableTimeoutID = null;

    // How long a connection needs to be stable for us to say
    // we're connected (in milliseconds).
    this._stablePeriod = 2000;

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
                    this.toApp({error: "Send: Websocket not configured"});
                    return;
                }
                this._ws.send(JSON.stringify(data.body));
                return;
            default:
                this.toApp({error: "Unrecognised instruction"});
                return;
        }
    };

    // Open a websocket and set up the event handlers.
    // Opening a second websocket will close the first one.
    this.open = function(url) {
        this._ws = this._newWebSocket(url);
        top._sendConnEnv('connecting');

        this._ws.onopen = function(evt) {
            // We've got an open connection

            // Take action when this connection is deemed stable
            top._stableTimeoutID =
                setTimeout(function() {
                    top._sendConnEnv('opened');
                }, top._stablePeriod);
        }

        this._ws.onclose = async function(evt) {
            // We've got an close connection.

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
                // Need to reconnect; tell the app
                top._sendConnEnv('connecting');
                url = top._makeConnURL(top._baseURL);
                await new Promise(r => setTimeout(r, top._delay()));
                top.open(url);
                return;
            }

            // We accept this close
            top._sendConnEnv('closed');
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
            // We've got an envelope from the server

            // An envelope means we've got a stable connection
            clearTimeout(top._stableTimeoutID);
            top._sendConnEnv('opened');

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
            top.toApp(env);
        }

        this._ws.onerror = function(evt) {
            // We've got an error from the websocket.

            // Error details can't be determined by design. See
            // https://stackoverflow.com/a/31003057/1830955
            // The browser will also close the websocket
            // Only pass on the error if wouldn't want to reconnect
            if (top._baseURL == null) {
                top.toApp({error: "Websocket error"});
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

    // Send a connection envelope to the app, but each message should
    // only be sent once in succession.
    this._sendConnEnv = function(state) {
        if (top._lastConnEnv != state) {
            top.toApp({connection: state});
            top._lastConnEnv = state;
        }
    };
};

// Export the object if we're calling this as a module (e.g. when testing).
if (typeof exports !== 'undefined') {
    exports.BoardGameFramework = BoardGameFramework;
}
