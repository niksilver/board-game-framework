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
    let urlUsed = null;

    // Create a BGF with a stub websocket
    bgf = new BGF.BoardGameFramework();
    bgf._newWebSocket = function(url) {
        urlUsed = url;
        return new EmptyWebSocket();
    };
    bgf._delay = function(){ return 1; };

    // Do the open action
    bgf.act({ instruction: 'Open', url: 'wss://my.test.url/g/my-id'});

    // Check the websocket was created
    t.equal(urlUsed, 'wss://my.test.url/g/my-id');

    // Tell tape we're done
    t.end();
});

test('Disconnection means a retry at least once', function(t) {
    // Count the number of connections; first will succeed, then
    // we'll cut it; second will succeed.
    let connections = 0;
    let websocket;

    // Create a BGF with a stub websocket
    bgf = new BGF.BoardGameFramework();
    bgf.toapp = function(env) {};
    bgf._newWebSocket = function(url) {
        ++connections;
        websocket = new EmptyWebSocket();
        return websocket;
    };
    bgf._delay = function(){ return 1; };

    // Do the open action, register onopen, then cut the connection once
    bgf.act({ instruction: 'Open', url: 'wss://my.test.url/g/my-id'});
    websocket.onopen({});

    t.equal(connections, 1);

    websocket.onclose({}).then(result => {
        t.equal(connections, 2);

        // Tell tape we're done
        t.end();
    });
});

test('Disconnection means continuous retries', function(t) {
    // Count the number of connections; first will succeed, then we'll
    // keep refusing
    let connections = 0;
    let websocket;

    // Create a BGF with a stub websocket
    bgf = new BGF.BoardGameFramework();
    bgf.toapp = function(env) {};
    bgf._newWebSocket = function(url) {
        ++connections;
        websocket = new EmptyWebSocket();
        return websocket;
    };
    bgf._delay = function(){ return 1; };

    // Do the open action, register onopen, then cut the connection once
    bgf.act({ instruction: 'Open', url: 'wss://my.test.url/g/my-id'});
    websocket.onopen({});

    t.equal(connections, 1);

    // We will repeatedly (a) check we tried to reconnect, and (b) close
    // the connection. We should see the connection counter incrementing.

    let tests = async function() {
        await websocket.onclose({});

        t.equal(connections, 2);
        await websocket.onclose({});

        t.equal(connections, 3);
        await websocket.onclose({});

        t.equal(connections, 4);
        await websocket.onclose({});

        t.equal(connections, 5);
        await websocket.onclose({});

        t.equal(connections, 6);
    };

    tests().then(result => {
        // Tell tape we're done
        t.end();
    });
});

test('Connecting with bad lastnum reconnects as new', function(t) {
    // Last URL connected
    let lastURL = null;

    // Create a BGF with a stub websocket
    bgf = new BGF.BoardGameFramework();
    bgf.toapp = function(env) {};
    bgf._newWebSocket = function(url) {
        lastURL = url;
        console.log("fn: url = " + url);
        websocket = new EmptyWebSocket();
        return websocket;
    };
    bgf._delay = function(){ return 1; };

    // Do the open action, then simulate the server closing the websocket
    // with a bad lastnum
    // Connect okay; close for some reason; ensure we reconnect with a
    // bad lastnum; expect a reconnection with no lastnum.
    bgf.act({ instruction: 'Open', url: 'ws://my.test.server/g/gameid'});

    let tests = async function() {
        // Open, increase the num to a bad value, close
        websocket.onopen({});
        bgf._num = 1000;
        await websocket.onclose({});

        // Check we've reconnected with the lastnum, then close
        // due to bad lastnum
        t.match(lastURL, /lastnum=1000/);
        websocket.onopen({});
        await websocket.onclose({ code: 4000, reason: 'Bad lastnum' });

        // Check we've reconnected with no lastnum
        if (lastURL.includes('lastnum')) {
            t.fail("Wwbsocket reconnection with bad lastnum. URL is " +
                lastURL);
        }
    };

    tests().then(result => {
        // Tell tape we're done
        t.end();
    });
});

test('Sends reconnecting envelope just once when reconnecting', function(t) {
    // Track the last envelope sent to the client
    let envelope = null;
    let websocket;

    // Create a BGF with a stub websocket
    bgf = new BGF.BoardGameFramework();
    bgf.toapp = function(env) {
        envelope = env;
    };
    bgf._newWebSocket = function(url) {
        websocket = new EmptyWebSocket();
        return websocket;
    };
    bgf._delay = function(){ return 1; };

    // Do the open action, register onopen, then cut the connection once
    bgf.act({ instruction: 'Open', url: 'wss://my.test.url/g/my-id'});
    websocket.onopen({});

    // We will repeatedly close the connection and expect to get
    // an envelope saying we're reconnecting. Then we'll check there
    // are no more after that.

    let tests = async function() {
        await websocket.onclose({});
        t.deepEqual(envelope,
            {reconnecting: true},
            'Expected to receive reconnecting envelope');
        envelope = 'Dummy untouched value';

        await websocket.onclose({});
        t.equal(envelope, 'Dummy untouched value');

        await websocket.onclose({});
        t.equal(envelope, 'Dummy untouched value');

        await websocket.onclose({});
        t.equal(envelope, 'Dummy untouched value');
    };

    tests().then(result => {
        // Tell tape we're done
        t.end();
    });
});

test('Sends second reconnecting env after stable connection', function(t) {
    // Track the last envelope sent to the client
    let envelope = null;
    let websocket;

    // Create a BGF with a stub websocket
    bgf = new BGF.BoardGameFramework();
    bgf._stablePeriod = 500;
    bgf.toapp = function(env) {
        envelope = env;
    };
    bgf._newWebSocket = function(url) {
        websocket = new EmptyWebSocket();
        return websocket;
    };
    bgf._delay = function(){ return 1; };

    // Do the open action, register onopen, then cut the connection once
    bgf.act({ instruction: 'Open', url: 'wss://my.test.url/g/my-id'});
    websocket.onopen({});

    // We will repeatedly close the connection and expect to get
    // an envelope saying we're reconnecting. Then we'll check there
    // are no more after that.

    let tests = async function() {
        await websocket.onclose({});
        t.deepEqual(envelope,
            {reconnecting: true},
            'Expected to receive reconnecting envelope');
        envelope = 'Dummy untouched value';

        await websocket.onclose({});
        t.equal(envelope, 'Dummy untouched value');

        // Confirm the connection, then wait for it to become stable
        console.log("Test: Calling second onopen");
        websocket.onopen({});
        await new Promise(r => setTimeout(r, bgf._stablePeriod * 1.5));

        await websocket.onclose({});
        t.deepEqual(envelope,
            {reconnecting: true},
            'Expected to receive second reconnecting envelope');
    };

    tests().then(result => {
        // Tell tape we're done
        t.end();
    });
});

