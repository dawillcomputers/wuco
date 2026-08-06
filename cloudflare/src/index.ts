export interface Env {
  WEA_DB: D1Database;
  ALLOWED_ORIGIN: string;
}

const json = (body: unknown, status = 200, origin?: string) =>
  Response.json(body, {
    status,
    headers: {
      'Access-Control-Allow-Origin': origin ?? 'null',
      'Access-Control-Allow-Methods': 'GET, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type',
      Vary: 'Origin',
    },
  });

export default {
  async fetch(request, env): Promise<Response> {
    const origin = request.headers.get('Origin');
    const allowedOrigin = origin == env.ALLOWED_ORIGIN ? origin : undefined;

    if (request.method == 'OPTIONS') {
      return new Response(null, {
        headers: {
          'Access-Control-Allow-Origin': allowedOrigin ?? 'null',
          'Access-Control-Allow-Methods': 'GET, OPTIONS',
          'Access-Control-Allow-Headers': 'Content-Type',
          Vary: 'Origin',
        },
      });
    }

    const url = new URL(request.url);
    if (request.method == 'GET' && url.pathname == '/api/health') {
      const result = await env.WEA_DB.prepare('SELECT value FROM app_metadata WHERE key = ?1')
          .bind('service_status')
          .first<{value: string}>();
      return json({ service: 'wuco-api', status: result?.value ?? 'ready' }, 200, allowedOrigin);
    }

    return json({ error: 'Not found' }, 404, allowedOrigin);
  },
} satisfies ExportedHandler<Env>;
