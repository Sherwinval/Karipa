import assert from 'node:assert/strict';
import { EventEmitter } from 'node:events';
import { PassThrough } from 'node:stream';
import test from 'node:test';
import { cloudflaredInstallInstructions, extractQuickTunnelUrl, getCloudflaredEnvironment, observeTunnelProcess, publishTunnelUrl, redactTunnelSecrets, stopChild, waitForTunnelHealth } from './dev-with-tunnel.mjs';
import tunnelDiscovery from '../tunnel-discovery/worker.js';

test('extracts only HTTPS Quick Tunnel URLs from cloudflared output', () => {
  assert.equal(
    extractQuickTunnelUrl('Your quick Tunnel has been created! Visit https://green-bird.trycloudflare.com'),
    'https://green-bird.trycloudflare.com',
  );
  assert.equal(extractQuickTunnelUrl('Connected to https://example.com'), null);
});

test('provides Windows cloudflared installation instructions', () => {
  const instructions = cloudflaredInstallInstructions('win32');
  assert.match(instructions, /winget install --id Cloudflare\.cloudflared/);
  assert.match(instructions, /developers\.cloudflare\.com/);
});

test('does not pass discovery credentials to cloudflared', () => {
  const environment = getCloudflaredEnvironment({
    PATH: 'C:\\tools',
    KARIPA_TUNNEL_DISCOVERY_URL: 'https://discovery.example/api/tunnel',
    KARIPA_TUNNEL_DISCOVERY_TOKEN: 'secret-token',
  });
  assert.equal(environment.PATH, 'C:\\tools');
  assert.equal('KARIPA_TUNNEL_DISCOVERY_URL' in environment, false);
  assert.equal('KARIPA_TUNNEL_DISCOVERY_TOKEN' in environment, false);
});

test('redacts discovery secrets from cloudflared output', () => {
  assert.equal(
    redactTunnelSecrets('token=secret-token', ['secret-token']),
    'token=[REDACTED]',
  );
});

test('captures URLs from both cloudflared output streams', async () => {
  const child = new EventEmitter();
  child.stdout = new PassThrough();
  child.stderr = new PassThrough();
  const found = [];
  const exited = new Promise((resolve) => {
    observeTunnelProcess(child, {
      onUrl: (url) => found.push(url),
      onError: (error) => assert.fail(error.message),
      onExit: resolve,
    });
  });

  child.stdout.write('https://first.trycloudflare.com\n');
  child.stderr.write('https://second.trycloudflare.com\n');
  child.emit('close', 0, null);
  await exited;
  assert.deepEqual(found, [
    'https://first.trycloudflare.com',
    'https://second.trycloudflare.com',
  ]);
});

test('publishes the URL with a secret header without logging it', async () => {
  const originalFetch = globalThis.fetch;
  let published;
  globalThis.fetch = async (endpoint, options) => {
    published = { endpoint, options };
    return new Response(null, { status: 200 });
  };
  try {
    await publishTunnelUrl(
      { endpoint: 'https://discovery.example/api/tunnel', token: 'private-test-token' },
      'https://fresh.trycloudflare.com',
    );
    assert.equal(published.endpoint, 'https://discovery.example/api/tunnel');
    assert.equal(published.options.headers.Authorization, 'Bearer private-test-token');
    assert.deepEqual(JSON.parse(published.options.body), {
      url: 'https://fresh.trycloudflare.com',
    });
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test('waits for the public API health check before declaring the tunnel ready', async () => {
  const originalFetch = globalThis.fetch;
  const requests = [];
  globalThis.fetch = async (url) => {
    requests.push(url);
    return new Response('{"success":true}', { status: 200 });
  };
  try {
    assert.equal(
      await waitForTunnelHealth(
        'https://ready.trycloudflare.com',
        () => true,
        () => false,
        1,
        0,
      ),
      true,
    );
    assert.deepEqual(requests, [
      'https://ready.trycloudflare.com/api/health',
    ]);
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test('keeps checking until a delayed public tunnel health check succeeds', async () => {
  const originalFetch = globalThis.fetch;
  let requestCount = 0;
  globalThis.fetch = async () => {
    requestCount++;
    return requestCount === 1
      ? new Response('Tunnel is starting', { status: 530 })
      : new Response('{"success":true}', { status: 200 });
  };
  try {
    assert.equal(
      await waitForTunnelHealth(
        'https://starting.trycloudflare.com',
        () => true,
        () => false,
        3,
        0,
      ),
      true,
    );
    assert.equal(requestCount, 2);
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test('discovery Worker publishes, serves, rejects unauthorized updates, and clears URLs', async () => {
  const values = new Map();
  const env = {
    PUBLISH_TOKEN: 'test-secret',
    TUNNEL_URLS: {
      get: async (key) => values.get(key) ?? null,
      put: async (key, value) => values.set(key, value),
      delete: async (key) => values.delete(key),
    },
  };
  const call = (method, body, token = 'test-secret') => tunnelDiscovery.fetch(
    new Request('https://discovery.example/api/tunnel', {
      method,
      headers: {
        ...(body ? { 'Content-Type': 'application/json' } : {}),
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
      },
      ...(body ? { body: JSON.stringify(body) } : {}),
    }),
    env,
  );

  assert.equal((await call('GET')).status, 503);
  assert.equal((await call('POST', { url: 'https://new.trycloudflare.com' }, 'wrong')).status, 401);
  assert.equal((await call('POST', { url: 'https://example.com' })).status, 400);
  assert.equal((await call('POST', { url: 'https://new.trycloudflare.com' })).status, 200);
  const discovered = await call('GET');
  assert.equal(discovered.status, 200);
  assert.deepEqual(await discovered.json(), {
    success: true,
    url: 'https://new.trycloudflare.com',
  });
  assert.equal((await call('DELETE')).status, 200);
  assert.equal((await call('GET')).status, 503);
});

test('terminates child processes during shutdown', async () => {
  const child = new EventEmitter();
  child.exitCode = null;
  child.signalCode = null;
  child.kill = (signal) => {
    assert.equal(signal, 'SIGTERM');
    setImmediate(() => {
      child.exitCode = 0;
      child.emit('close', 0, null);
    });
    return true;
  };

  await stopChild(child);
  assert.equal(child.exitCode, 0);
});
