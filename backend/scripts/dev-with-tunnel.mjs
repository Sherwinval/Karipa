import { spawn } from 'node:child_process';
import { readFile, unlink, writeFile } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import dotenv from 'dotenv';

const backendDirectory = resolve(dirname(fileURLToPath(import.meta.url)), '..');
dotenv.config({ path: [resolve(backendDirectory, '.env'), resolve(backendDirectory, '..', '.env')] });
const port = Number(process.env.PORT || 3000);
const localApiOrigin = `http://localhost:${port}`;
const tsxCli = resolve(backendDirectory, 'node_modules/tsx/dist/cli.mjs');
const tunnelUrlFile = resolve(backendDirectory, '.tunnel-url');
const lockFile = resolve(backendDirectory, '.dev-tunnel.lock');
const quickTunnelPattern = /https:\/\/[a-z0-9-]+\.trycloudflare\.com\b/i;

export function extractQuickTunnelUrl(line) {
  return line.match(quickTunnelPattern)?.[0] ?? null;
}

export function cloudflaredInstallInstructions(platform = process.platform) {
  if (platform === 'win32') {
    return [
      'Install Cloudflare Tunnel on Windows, then open a new terminal:',
      '  winget install --id Cloudflare.cloudflared --exact',
      'Or download cloudflared from https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/.',
    ].join('\n');
  }
  return 'Install cloudflared from https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/, then restart npm run dev.';
}

function isProcessRunning(pid) {
  if (!Number.isInteger(pid) || pid <= 0) return false;
  try {
    process.kill(pid, 0);
    return true;
  } catch (error) {
    if (error.code === 'EPERM') return true;
    if (error.code === 'ESRCH') return false;
    throw error;
  }
}

async function acquireLock() {
  for (let attempt = 0; attempt < 2; attempt += 1) {
    try {
      await writeFile(lockFile, `${process.pid}\n`, { flag: 'wx' });
      return;
    } catch (error) {
      if (error.code !== 'EEXIST') throw error;
      const lockContents = await readFile(lockFile, 'utf8').catch((readError) => {
        if (readError.code === 'ENOENT') return '';
        throw readError;
      });
      const existingPid = Number.parseInt(lockContents.trim(), 10);
      if (isProcessRunning(existingPid)) {
        throw new Error(
          `Another Karipa development server is running (PID ${existingPid}).`,
        );
      }
      await unlink(lockFile).catch((unlinkError) => {
        if (unlinkError.code !== 'ENOENT') throw unlinkError;
      });
    }
  }
  throw new Error('Could not acquire the Karipa development startup lock.');
}

async function removeTunnelUrlFile() {
  await unlink(tunnelUrlFile).catch((error) => {
    if (error.code !== 'ENOENT') {
      console.error(`Could not remove ${tunnelUrlFile}: ${error.message}`);
    }
  });
}

function forwardOutput(stream, write, onLine = () => {}) {
  let pending = '';
  stream.setEncoding('utf8');
  stream.on('data', (chunk) => {
    pending += chunk;
    const lines = pending.split(/\r?\n/);
    pending = lines.pop() ?? '';
    for (const line of lines) {
      write(line);
      onLine(line);
    }
  });
  stream.on('end', () => {
    if (pending) {
      write(pending);
      onLine(pending);
    }
  });
}

export function observeTunnelProcess(child, handlers) {
  let spawnError;
  const onTunnelOutput = (line) => {
    const url = extractQuickTunnelUrl(line);
    if (url) handlers.onUrl(url);
  };

  forwardOutput(
    child.stdout,
    (line) => console.log(`[cloudflared] ${line}`),
    onTunnelOutput,
  );
  forwardOutput(
    child.stderr,
    (line) => console.error(`[cloudflared] ${line}`),
    onTunnelOutput,
  );
  child.on('error', (error) => {
    spawnError = error;
    handlers.onError(error);
  });
  child.on('close', (code, signal) => {
    handlers.onExit({ code, signal, spawnError });
  });
}

function delay(milliseconds) {
  return new Promise((resolveDelay) => setTimeout(resolveDelay, milliseconds));
}

function getDiscoveryConfiguration() {
  const endpoint = process.env.KARIPA_TUNNEL_DISCOVERY_URL?.trim();
  const token = process.env.KARIPA_TUNNEL_DISCOVERY_TOKEN?.trim();
  if (!endpoint && !token) return null;
  if (!endpoint || !token) {
    throw new Error(
      'Set both KARIPA_TUNNEL_DISCOVERY_URL and KARIPA_TUNNEL_DISCOVERY_TOKEN in backend/.env.',
    );
  }
  const parsedEndpoint = new URL(endpoint);
  if (parsedEndpoint.protocol !== 'https:') {
    throw new Error('KARIPA_TUNNEL_DISCOVERY_URL must use HTTPS.');
  }
  return { endpoint: parsedEndpoint.toString(), token };
}

export async function publishTunnelUrl(configuration, url, method = 'POST') {
  if (!configuration) return;
  const response = await fetch(configuration.endpoint, {
    method,
    headers: {
      Authorization: `Bearer ${configuration.token}`,
      ...(method === 'POST' ? { 'Content-Type': 'application/json' } : {}),
    },
    ...(method === 'POST' ? { body: JSON.stringify({ url }) } : {}),
    signal: AbortSignal.timeout(5000),
  });
  if (!response.ok) {
    throw new Error(`Discovery service returned HTTP ${response.status}.`);
  }
}

async function updateDiscoveryUntilPublished(configuration, url, isCurrent, isShuttingDown) {
  for (let attempt = 0; attempt < 5 && isCurrent() && !isShuttingDown(); attempt += 1) {
    try {
      await publishTunnelUrl(configuration, url);
      console.log('DISCOVERY STATUS: Current tunnel URL published.');
      return;
    } catch (error) {
      if (attempt === 4) {
        console.error(`Could not publish tunnel URL to the discovery service: ${error.message}`);
        return;
      }
      await delay(1000);
    }
  }
}

async function waitForTunnelHealth(url, isCurrentTunnel, isShuttingDown) {
  for (let attempt = 0; attempt < 60 && isCurrentTunnel() && !isShuttingDown(); attempt += 1) {
    try {
      const response = await fetch(`${url}/api/health`, {
        signal: AbortSignal.timeout(3000),
      });
      if (response.ok) {
        const body = await response.json();
        if (body.success === true) {
          console.log(`TUNNEL STATUS: CONNECTED (${response.status} health check)`);
          return;
        }
      }
    } catch {
      // The public hostname can be assigned before the tunnel is ready.
    }
    await delay(1000);
  }

  if (isCurrentTunnel() && !isShuttingDown()) {
    console.warn('TUNNEL STATUS: URL assigned, but the public health check did not succeed.');
  }
}

function waitForClose(child, timeoutMilliseconds = 5000) {
  if (child.exitCode !== null || child.signalCode !== null) {
    return Promise.resolve();
  }

  return new Promise((resolveClose) => {
    const timeout = setTimeout(() => child.kill('SIGKILL'), timeoutMilliseconds);
    child.once('close', () => {
      clearTimeout(timeout);
      resolveClose();
    });
  });
}

export async function stopChild(child) {
  if (!child || child.exitCode !== null || child.signalCode !== null) return;
  child.kill('SIGTERM');
  await waitForClose(child);
}

export async function runDevelopmentServer() {
  try {
    await acquireLock();
  } catch (error) {
    console.error(error.message);
    return 1;
  }

  await removeTunnelUrlFile();
  console.log(`KARIPA BACKEND: ${localApiOrigin}`);

  let server;
  let tunnel;
  let shuttingDown = false;
  let tunnelUrl = null;
  let urlWrite = Promise.resolve();
  let discoveryUpdate = Promise.resolve();
  let discoveryCleanup = Promise.resolve();
  let discoveryConfiguration;

  try {
    discoveryConfiguration = getDiscoveryConfiguration();
  } catch (error) {
    console.error(error.message);
  }

  try {
    server = spawn(process.execPath, [tsxCli, 'watch', 'src/server.ts'], {
      cwd: backendDirectory,
      stdio: ['inherit', 'pipe', 'pipe'],
      windowsHide: true,
    });
  } catch (error) {
    console.error(`Could not start the Karipa backend: ${error.message}`);
    await removeTunnelUrlFile();
    await unlink(lockFile).catch(() => {});
    return 1;
  }

  server.stdout.pipe(process.stdout);
  server.stderr.pipe(process.stderr);

  try {
    tunnel = spawn('cloudflared', ['tunnel', '--url', localApiOrigin], {
      cwd: backendDirectory,
      stdio: ['ignore', 'pipe', 'pipe'],
      windowsHide: true,
    });
  } catch (error) {
    console.error(`Could not start cloudflared: ${error.message}`);
    console.error(cloudflaredInstallInstructions());
  }

  if (tunnel) {
    observeTunnelProcess(tunnel, {
      onUrl: (url) => {
        if (tunnelUrl === url) return;
        tunnelUrl = url;
        console.log(`KARIPA PUBLIC API: ${url}`);
        console.log('TUNNEL STATUS: CONNECTING');
        urlWrite = writeFile(tunnelUrlFile, `${url}\n`, 'utf8').catch((error) => {
          console.error(`Could not save the tunnel URL: ${error.message}`);
        });
        if (!discoveryConfiguration) {
          console.warn(
            'DISCOVERY STATUS: Not configured. The mobile app cannot discover new tunnel URLs until a stable discovery service is configured.',
          );
        } else {
          discoveryUpdate = updateDiscoveryUntilPublished(
            discoveryConfiguration,
            url,
            () => tunnelUrl === url,
            () => shuttingDown,
          );
        }
        void waitForTunnelHealth(
          url,
          () => tunnelUrl === url,
          () => shuttingDown,
        );
      },
      onError: (error) => {
        if (error.code === 'ENOENT') {
          console.error('cloudflared was not found on PATH. The backend will continue without a public tunnel.');
          console.error(cloudflaredInstallInstructions());
        } else {
          console.error(`Could not start cloudflared: ${error.message}`);
        }
      },
      onExit: ({ code, signal, spawnError }) => {
        if (tunnelUrl) {
          const previousUrl = tunnelUrl;
          tunnelUrl = null;
          console.warn(`TUNNEL STATUS: DISCONNECTED (code ${code ?? 'none'}, signal ${signal ?? 'none'})`);
          discoveryCleanup = Promise.all([urlWrite, discoveryUpdate]).then(async () => {
            await removeTunnelUrlFile();
            if (discoveryConfiguration) {
              await publishTunnelUrl(discoveryConfiguration, previousUrl, 'DELETE').catch((error) => {
                if (!shuttingDown) {
                  console.error(`Could not clear the discovery URL: ${error.message}`);
                }
              });
            }
          });
        }
        if (!shuttingDown && !spawnError && code !== 0) {
          console.error('Cloudflare Tunnel stopped unexpectedly; the backend will keep running.');
        }
      },
    });
  } else {
    console.error('The backend will continue running without a public tunnel.');
  }

  let resolveStop;
  const stopRequested = new Promise((resolveStopRequest) => {
    resolveStop = resolveStopRequest;
  });
  const handleSignal = (signal) => resolveStop({ signal });
  const handleServerError = (error) => {
    console.error(`Karipa backend process failed: ${error.message}`);
    resolveStop({ code: 1 });
  };
  const handleServerClose = (code, signal) => resolveStop({ code, signal });

  process.once('SIGINT', handleSignal);
  process.once('SIGTERM', handleSignal);
  server.once('error', handleServerError);
  server.once('close', handleServerClose);

  const stopped = await stopRequested;
  shuttingDown = true;
  console.log('Stopping Karipa backend and Cloudflare Tunnel...');
  await Promise.all([stopChild(tunnel), stopChild(server)]);
  await urlWrite;
  await discoveryCleanup;
  await removeTunnelUrlFile();
  await unlink(lockFile).catch((error) => {
    if (error.code !== 'ENOENT') {
      console.error(`Could not remove startup lock: ${error.message}`);
    }
  });
  process.removeListener('SIGINT', handleSignal);
  process.removeListener('SIGTERM', handleSignal);

  if (stopped.signal) {
    console.log(`Karipa development server stopped (${stopped.signal}).`);
    return 0;
  }
  return stopped.code ?? 0;
}

const invokedPath = process.argv[1] ? resolve(process.argv[1]) : '';
if (invokedPath && pathToFileURL(invokedPath).href === import.meta.url) {
  process.exitCode = await runDevelopmentServer();
}
