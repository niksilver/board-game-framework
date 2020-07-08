var test = require('tape');
var BGF = require('./board-game-framework.js');

// There's no application to receive envelopes

// Constructor for a dummy websocket
var EmptyWebSocket = function() {
    this.onopen = function(evt){};
    this.onclose = function(evt){};
    this.onmessage = function(evt){};
}

test('example test', function(t) {
    t.equal(2+2, 4);

    // Tell tape we're done
    t.end();
});

test('Open action creates websocket', function(t) {
    // To check we called open, and used the right URL
    var urlUsed = null;

    // Create a BGF with a stub websocket
    bgf = new BGF.BoardGameFramework();
    bgf._newWebSocket = function(url) {
        urlUsed = url;
        return new EmptyWebSocket();
    };

    // Do the open action
    bgf.act({ instruction: 'Open', url: 'wss://my.test.url'});

    // Check the websocket was created
    t.equal(urlUsed, 'wss://my.test.url');

    // Tell tape we're done
    t.end();
});

test('Disconnection means a retry at least once', function(t) {
    // Count the number of connections; first will succeed, then
    // we'll cut it; second will succeed.
    var connections = 0;
    var websocket;

    // Create a BGF with a stub websocket
    bgf = new BGF.BoardGameFramework();
    bgf.toapp = function(env) {};
    bgf._newWebSocket = function(url) {
        ++connections;
        websocket = new EmptyWebSocket();
        return websocket;
    };

    // Do the open action, register onopen, then cut the connection once
    bgf.act({ instruction: 'Open', url: 'wss://my.test.url'});
    websocket.onopen({});

    t.equal(connections, 1);

    websocket.onclose({}).then(result => {
        t.equal(connections, 2);

        // Tell tape we're done
        t.end();
    });
});

test('Disconnection means max 4 retries', function(t) {
    // Count the number of connections; first will succeed, then
    // we'll cut it; second will succeed.
    var connections = 0;
    var websocket;

    // Create a BGF with a stub websocket
    bgf = new BGF.BoardGameFramework();
    bgf.toapp = function(env) {};
    bgf._newWebSocket = function(url) {
        ++connections;
        websocket = new EmptyWebSocket();
        return websocket;
    };

    // Do the open action, register onopen, then cut the connection once
    bgf.act({ instruction: 'Open', url: 'wss://my.test.url'});
    websocket.onopen({});

    t.equal(connections, 1);

    // We will repeatedly (a) check we tried to reconnect, and (b) close
    // the connection. Eventually we should stop trying to reconnect,
    // as indicated by the connection counter no longer incrementing.

    var tests = async function() {
        await websocket.onclose({});

        t.equal(connections, 2);
        await websocket.onclose({});

        t.equal(connections, 3);
        await websocket.onclose({});

        t.equal(connections, 4);
        await websocket.onclose({});

        // Check we've not tried to connect again - same connection count
        t.equal(connections, 4);
    };

    tests().then(result => {
        // Tell tape we're done
        t.end();
    });
});

test('Connecting with bad lastnum reconnects just a few times', function(t) {
    // Tell tape we're done
    t.end();
});
