const legacyHost = "legacy.supaterm.com";
const productHosts = new Set(["supaterm.com", "www.supaterm.com"]);

export default {
  fetch(request: Request) {
    const url = new URL(request.url);
    if (!productHosts.has(url.hostname)) {
      return new Response("Not Found", { status: 404 });
    }

    url.hostname = legacyHost;
    return Response.redirect(url, 308);
  },
};
