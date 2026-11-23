const headers = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  'Cache-Control': 'no-store',
  'Content-Type': 'application/json; charset=utf-8',
};

function json(body, status = 200) {
  return new Response(JSON.stringify(body), { status, headers });
}

function isQuickTunnelUrl(value) {
  try {
    const url = new URL(value);
    return url.protocol === 'https:' &&
      url.hostname.endsWith('.trycloudflare.com') &&
      url.pathname === '/' &&
      !url.search &&
      !url.hash &&
      !url.username &&
      !url.password;
  } catch {
    return false;
  }
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (url.pathname !== '/api/tunnel') {
      return json({ success: false, message: 'Not found' }, 404);
    }

    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers });
    }

    if (request.method === 'GET') {
      const activeUrl = await env.TUNNEL_URLS.get('active-url');
      return activeUrl
        ? json({ success: true, url: activeUrl })
        : json({ success: false, message: 'No active tunnel is published' }, 503);
    }

    if (!env.PUBLISH_TOKEN ||
        request.headers.get('Authorization') !== `Bearer ${env.PUBLISH_TOKEN}`) {
      return json({ success: false, message: 'Unauthorized' }, 401);
    }

    if (request.method === 'POST') {
      let payload;
      try {
        payload = await request.json();
      } catch {
        return json({ success: false, message: 'Invalid JSON body' }, 400);
      }
      if (typeof payload.url !== 'string' || !isQuickTunnelUrl(payload.url)) {
        return json({ success: false, message: 'Invalid Quick Tunnel URL' }, 400);
      }
      await env.TUNNEL_URLS.put('active-url', payload.url);
      return json({ success: true });
    }

    if (request.method === 'DELETE') {
      await env.TUNNEL_URLS.delete('active-url');
      return json({ success: true });
    }

    return json({ success: false, message: 'Method not allowed' }, 405);
  },
};
