const legacyHost = "legacy.supaterm.com";
const productHosts = new Set(["supaterm.com", "www.supaterm.com"]);
const legacyUrl = `https://${legacyHost}/`;
const comingSoonPage = (redirectUrl: string) => `<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta http-equiv="refresh" content="2;url=${redirectUrl}">
    <title>Supaterm — Coming soon</title>
    <style>
      :root { color-scheme: dark; font-family: ui-monospace, SFMono-Regular, Menlo, monospace; }
      body { display: grid; min-height: 100vh; margin: 0; place-items: center; background: #101010; color: #f5f5f5; }
      main { width: min(32rem, calc(100% - 3rem)); }
      p { color: #a8a8a8; }
      a { color: #f5f5f5; }
    </style>
  </head>
  <body>
    <main>
      <h1>Coming soon</h1>
      <p>Looking for the terminal</p>
      <a href="${redirectUrl}">Go to legacy.supaterm.com</a>
    </main>
    <script>window.setTimeout(() => window.location.replace("${redirectUrl}"), 2000);</script>
  </body>
</html>`;

export default {
  fetch(request: Request) {
    const url = new URL(request.url);
    if (!productHosts.has(url.hostname)) {
      return new Response("Not Found", { status: 404 });
    }

    if (url.pathname === "/") {
      return new Response(comingSoonPage(`${legacyUrl}${url.search}`), {
        headers: {
          "cache-control": "no-store",
          "content-type": "text/html; charset=utf-8",
          "referrer-policy": "no-referrer",
        },
      });
    }

    url.hostname = legacyHost;
    return Response.redirect(url, 308);
  },
};
