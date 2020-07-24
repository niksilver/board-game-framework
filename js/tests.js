var test = require('tape');
var BGF = require('./board-game-framework.js');

function sleep(ms) {
    return new Promise(r => setTimeout(r, ms));
}

// There's no application to receive envelopes

// Constructor for a dummy websocket
var EmptyWebSocket = function() {
    this.onopen = function(evt){};
    this.onclose = function(evt){};
    this.onmessage = function(evt){};
}

// In the tests below we have to simulate when the websocket would
// call an onopen, onclose, etc.

test.skip('example test', function(t) {
    t.equal(2+2, 4);

    // Tell tape we're done
    t.end();
});

test('New BGF object generates client ID', function(t) {
    // To check we called open, and used the right URL
    let urlUsed = null;

    bgf = new BGF.BoardGameFramework();
    bgf.toApp = function(env){};
    bgf._newWebSocket = function(url) {
        urlUsed = url;
        return new EmptyWebSocket();
    };

    if (typeof(bgf.id) != 'string') {
        t.fail("Type of client ID '" + bgf.id + "' is '" +
            typeof(bgf.id) + "' but should be string");
    } else {
        t.pass();
    }
    if (bgf.id.length <= 10) {
        t.fail("Client ID '" + bgf.id + "' is too short");
    } else {
        t.pass();
    }

    // Make sure the websocket we open includes this ID
    bgf.act({ instruction: 'Open', url: 'wss://some.id.test/g/game-id'});
    substr = 'id=' + bgf.id;
    if (!urlUsed.includes(substr)) {
        t.fail("URL used ('') should have included '" + substr +
            "' but it did not");
    } else {
        t.pass();
    }

    t.end();
});

test('Open action creates websocket', function(t) {
    // To check we called open, and used the right URL
    let urlUsed = null;

    // Create a BGF with a stub websocket
    bgf = new BGF.BoardGameFramework();
    bgf.toApp = function(env){};
    bgf._newWebSocket = function(url) {
        urlUsed = url;
        return new EmptyWebSocket();
    };
    bgf._delay = function(){ return 1; };

    // Do the open action
    bgf.act({ instruction: 'Open', url: 'wss://my.test.url/g/my-id'});

    // Check the websocket was created
    t.equal(urlUsed, 'wss://my.test.url/g/my-id?id=' + bgf.id);

    // Tell tape we're done
    t.end();
});

test('Open action sends connecting envelope', function(t) {
    // To check we called open, and used the right URL
    let urlUsed = null;
    // The last envelope sent to the web app
    let envelope = 'Not set';

    // Create a BGF with a stub websocket
    bgf = new BGF.BoardGameFramework();
    bgf.toApp = function(env) { envelope = env; };
    bgf._newWebSocket = function(url) {
        urlUsed = url;
        return new EmptyWebSocket();
    };
    bgf._delay = function(){ return 1; };

    // Do the open action
    bgf.act({ instruction: 'Open', url: 'wss://my.test.url/g/my-id'});

    // Check connecting envelope was sent
    t.deepEqual({connection: 'connecting'}, envelope);

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
    bgf.toApp = function(env) {};
    bgf._newWebSocket = function(url) {
        ++connections;
        websocket = new EmptyWebSocket();
        return websocket;
    };
    bgf._delay = function(){ return 1; };

    let tests = async function() {
        // Do the open action, register onopen, then cut the connection once
        bgf.act({ instruction: 'Open', url: 'wss://my.test.url/g/my-id'});
        websocket.onopen({});

        t.equal(connections, 1);

        await websocket.onclose({});
        t.equal(connections, 2);
    };

    tests().then(result => {
        // Tell tape we're done
        t.end();
    });
});

test('Opened envelope sent only after stable period', function(t) {
    // Count the number of connections
    let connections = 0;
    // Last envelope sent to application
    let lastEnv = 'Untouched';
    let websocket;

    // Create a BGF with a stub websocket
    bgf = new BGF.BoardGameFramework();
    bgf.toApp = function(env) { lastEnv = env; };
    bgf._stablePeriod = 500;
    bgf._newWebSocket = function(url) {
        ++connections;
        websocket = new EmptyWebSocket();
        return websocket;
    };
    bgf._delay = function(){ return 1; };

    let tests = async function() {
        // Do the open action, register onopen, the expect the 'opened'
        // envelope only after the stable period.
        bgf.act({ instruction: 'Open', url: 'wss://my.test.url/g/my-id'});
        websocket.onopen({});

        t.equal(connections, 1);

        // No 'opened' envelope yet... but should be after the stable period
        t.deepEqual(lastEnv, {connection: 'connecting'});
        await sleep(bgf._stablePeriod * 1.5);
        t.deepEqual(lastEnv, {connection: 'opened'});
    };

    tests().then(result => {
        // Tell tape we're done
        t.end();
    });
});

test('Opened envelope sent as soon as message received', function(t) {
    // Count the number of connections
    let connections = 0;
    // List of envelopes sent to application
    let envelopes = [];
    let websocket;

    // Create a BGF with a stub websocket
    bgf = new BGF.BoardGameFramework();
    bgf.toApp = function(env) { envelopes.push(env); };
    bgf._stablePeriod = 500;
    bgf._newWebSocket = function(url) {
        ++connections;
        websocket = new EmptyWebSocket();
        return websocket;
    };
    bgf._delay = function(){ return 1; };

    let tests = async function() {
        // Do the open action, expect it to say it's connecting,
        // register onopen, then expect the 'opened'
        // envelope only after the stable period.
        bgf.act({ instruction: 'Open', url: 'wss://my.test.url/g/my-id'});
        t.deepEqual(envelopes, [{connection: 'connecting'}]);
        envelopes = [];
        websocket.onopen({});

        // Should have a connection, but no new envelope yet
        t.equal(connections, 1);
        t.deepEqual(envelopes, []);

        // Should get an 'opened' envelope as soon as a message is received
        // message is received
        websocket.onmessage({data: '{"my": "Test message"}'});
        t.deepEqual(envelopes, [{connection: 'opened'}, {my: 'Test message'}]);
    };

    tests().then(result => {
        // Tell tape we're done
        t.end();
    });
});

test('Should not get second Opened envelope after message received', function(t) {
    // Count the number of connections
    let connections = 0;
    // List of envelopes sent to application
    let envelopes = [];
    let websocket;

    // Create a BGF with a stub websocket
    bgf = new BGF.BoardGameFramework();
    bgf.toApp = function(env) { envelopes.push(env); };
    bgf._stablePeriod = 500;
    bgf._newWebSocket = function(url) {
        ++connections;
        websocket = new EmptyWebSocket();
        return websocket;
    };
    bgf._delay = function(){ return 1; };

    let tests = async function() {
        // Do the open action, expect a 'connecting' message,
        // register onopen, then expect the 'opened'
        // envelope only after the stable period.
        bgf.act({ instruction: 'Open', url: 'wss://my.test.url/g/my-id'});
        t.deepEqual(envelopes, [{connection: 'connecting'}]);
        envelopes = [];
        websocket.onopen({});

        // Should have a connection, but no new envelope yet
        t.equal(connections, 1);
        t.deepEqual(envelopes, []);

        // Should get an 'opened' envelope as soon as a message is received
        // message is received
        websocket.onmessage({data: '{"my": "Test message"}'});
        t.deepEqual(envelopes, [{connection: 'opened'}, {my: 'Test message'}]);

        // Shouldn't get another 'opened' envelope (e.g. from the original
        // onopen being declared stable).
        envelopes = [];
        await sleep(bgf._stablePeriod * 1.5);
        t.deepEqual(envelopes, []);
    };

    tests().then(result => {
        // Tell tape we're done
        t.end();
    });
});

test('Should not get second Opened envelope after second message', function(t) {
    // Count the number of connections
    let connections = 0;
    // List of envelopes sent to application
    let envelopes = [];
    let websocket;

    // Create a BGF with a stub websocket
    bgf = new BGF.BoardGameFramework();
    bgf.toApp = function(env) { envelopes.push(env); };
    bgf._stablePeriod = 500;
    bgf._newWebSocket = function(url) {
        ++connections;
        websocket = new EmptyWebSocket();
        return websocket;
    };
    bgf._delay = function(){ return 1; };

    let tests = async function() {
        // Do the open action, expect a 'connecting' envelope,
        // register onopen, then expect the 'opened'
        // envelope only after the stable period.
        bgf.act({ instruction: 'Open', url: 'wss://my.test.url/g/my-id'});
        t.deepEqual(envelopes, [{connection: 'connecting'}]);
        envelopes = [];
        websocket.onopen({});

        // Should have a connection, but no new envelope yet
        t.equal(connections, 1);
        t.deepEqual(envelopes, []);

        // Should get an 'opened' envelope as soon as a message is received
        // message is received
        websocket.onmessage({data: '{"my": "Test message"}'});
        t.deepEqual(envelopes, [{connection: 'opened'}, {my: 'Test message'}]);

        // Shouldn't get another 'opened' envelope, even if we get
        // another message.
        envelopes = [];
        websocket.onmessage({data: '{"my": "Second message"}'});
        t.deepEqual(envelopes, [{my: 'Second message'}]);
    };

    tests().then(result => {
        // Tell tape we're done
        t.end();
    });
});

test('Opened envelope not sent while reconnecting', function(t) {
    // Count the number of connections
    let connections = 0;
    // Last envelope sent to application
    let lastEnv = 'Untouched';
    let websocket;

    // Create a BGF with a stub websocket
    bgf = new BGF.BoardGameFramework();
    bgf.toApp = function(env) { lastEnv = env; };
    bgf._stablePeriod = 300;
    bgf._newWebSocket = function(url) {
        ++connections;
        websocket = new EmptyWebSocket();
        return websocket;
    };
    bgf._delay = function(){ return 1; };

    let tests = async function() {
        // Do the open action, expect a 'connecting' envelope,
        // register onopen, the expect the 'opened'
        // envelope only after the stable period.
        bgf.act({ instruction: 'Open', url: 'wss://my.test.url/g/my-id'});
        t.deepEqual(lastEnv, {connection: 'connecting'});
        lastEnv = 'Untouched';
        websocket.onopen({});

        t.equal(connections, 1);

        // No 'opened' envelope yet... and we'll cut the connection
        // before the stable period, repeatedly.

        t.equal(lastEnv, 'Untouched');
        lastEnv = 'Untouched'
        await sleep(bgf._stablePeriod * 0.5);
        await websocket.onclose({});

        t.equal(connections, 2);
        websocket.onopen({});
        t.equal(lastEnv, 'Untouched');
        lastEnv = 'Untouched'
        await sleep(bgf._stablePeriod * 0.5);
        await websocket.onclose({});

        t.equal(connections, 3);
        websocket.onopen({});
        t.equal(lastEnv, 'Untouched');
        lastEnv = 'Untouched'
        await sleep(bgf._stablePeriod * 0.5);
        await websocket.onclose({});

        // Should get one (and only one) 'opened' envelope
        t.equal(connections, 4);
        websocket.onopen({});
        await sleep(bgf._stablePeriod * 1.5);
        t.deepEqual(lastEnv, {connection: 'opened'});
        lastEnv = 'Untouched'
        await sleep(bgf._stablePeriod * 1.5);
        t.deepEqual(lastEnv, 'Untouched');
    };

    tests().then(result => {
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
    bgf.toApp = function(env) {};
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
        websocket.onopen({});
        await websocket.onclose({});

        t.equal(connections, 3);
        websocket.onopen({});
        await websocket.onclose({});

        t.equal(connections, 4);
        websocket.onopen({});
        await websocket.onclose({});

        t.equal(connections, 5);
        websocket.onopen({});
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
    bgf.toApp = function(env) {};
    bgf._newWebSocket = function(url) {
        lastURL = url;
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

test('Sends connecting envelope just once when reconnecting', function(t) {
    // Track the last envelope sent to the client
    let envelope = null;
    let websocket;

    // Create a BGF with a stub websocket
    bgf = new BGF.BoardGameFramework();
    bgf.toApp = function(env) {
        envelope = env;
    };
    bgf._newWebSocket = function(url) {
        websocket = new EmptyWebSocket();
        return websocket;
    };
    bgf._delay = function(){ return 1; };

    let tests = async function() {
        // Do the open action, expect a 'connecting' envelope,
        // register onopen, then cut the connection once
        bgf.act({ instruction: 'Open', url: 'wss://my.test.url/g/my-id'});
        t.deepEqual(envelope, {connection: 'connecting'});
        envelope = 'Dummy untouched value';
        websocket.onopen({});

        // We will repeatedly close the connection and expect to get
        // an envelope saying we're (re)connecting. Then we'll check there
        // are no more after that.

        await websocket.onclose({});
        t.equal(envelope, 'Dummy untouched value');
        envelope = 'Dummy untouched value';

        websocket.onopen({});
        await websocket.onclose({});
        t.equal(envelope, 'Dummy untouched value');

        websocket.onopen({});
        await websocket.onclose({});
        t.equal(envelope, 'Dummy untouched value');

        websocket.onopen({});
        await websocket.onclose({});
        t.equal(envelope, 'Dummy untouched value');
    };

    tests().then(result => {
        // Tell tape we're done
        t.end();
    });
});

test('Sends second connecting env after stable connection', function(t) {
    // Track the last envelope sent to the client
    let envelope = null;
    // Flag if we've created a new websocket
    let newWS = false;
    let websocket;

    // Create a BGF with a stub websocket
    bgf = new BGF.BoardGameFramework();
    bgf._stablePeriod = 500;
    bgf.toApp = function(env) {
        envelope = env;
    };
    bgf._newWebSocket = function(url) {
        newWS = true;
        websocket = new EmptyWebSocket();
        return websocket;
    };
    bgf._delay = function(){ return 1; };

    // Do the open action, register onopen, then cut the connection once
    bgf.act({ instruction: 'Open', url: 'wss://my.test.url/g/my-id'});
    websocket.onopen({});

    // We will repeatedly close the connection and expect to get
    // an envelope saying we're (re)connecting. Then we'll check there
    // are no more after that.

    let tests = async function() {
        await websocket.onclose({});
        t.deepEqual(envelope,
            {connection: 'connecting'},
            'Expected to receive connecting envelope');
        envelope = 'Dummy untouched value';

        // Check we've created a new websocket, then reset the flag
        t.equal(newWS, true);
        newWS = false;

        // Acknowledge the connection, then cut it
        websocket.onopen({});
        await websocket.onclose({});
        t.equal(envelope, 'Dummy untouched value');

        // Check we've created a new websocket, then reset the flag
        t.equal(newWS, true);
        newWS = false;

        // Acknowledge the connection, then wait for it to become stable
        websocket.onopen({});
        await new Promise(r => setTimeout(r, bgf._stablePeriod * 1.5));

        await websocket.onclose({});
        t.deepEqual(envelope,
            {connection: 'connecting'},
            'Expected to receive second connecting envelope');
    };

    tests().then(result => {
        // Tell tape we're done
        t.end();
    });
});

test.skip('Some tests to check Connected envelopes...', function(t) {
    // Tell tape we're done
    t.end();
});
