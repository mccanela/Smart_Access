export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const pathname = url.pathname;

    // Verifica se é um arquivo estático (tem extensão como .js, .css, .png, etc)
    const lastSegment = pathname.split('/').pop() || '';
    const isFile = lastSegment.includes('.');

    let response;

    if (!isFile && pathname !== '/') {
      // Rota do Flutter (ex: /summit, /rota/sid, /sid)
      // Servir index.html para o Flutter resolver
      const indexUrl = new URL('/index.html', url.origin);
      response = await env.ASSETS.fetch(new Request(indexUrl, {
        method: 'GET',
        headers: request.headers,
      }));

      // Criar nova response para evitar redirect e adicionar headers
      response = new Response(response.body, {
        status: 200,
        headers: response.headers,
      });
    } else {
      // Arquivo estático ou raiz — servir normalmente
      response = await env.ASSETS.fetch(request);
    }

    return response;
  },
};
