import assert from "node:assert/strict";

import worker from "./worker.ts";

for (const host of ["supaterm.com", "www.supaterm.com"]) {
  const query = host === "supaterm.com" ? "?source=home" : "";
  const expectedRedirectUrl = `https://legacy.supaterm.com/${query}`;
  const rootResponse = await worker.fetch(new Request(`https://${host}/${query}`));
  assert.equal(rootResponse.status, 200);
  assert.equal(rootResponse.headers.get("content-type"), "text/html; charset=utf-8");
  assert.equal(rootResponse.headers.get("cache-control"), "no-store");
  const rootPage = await rootResponse.text();
  assert.match(rootPage, /<h1>Coming soon<\/h1>/);
  assert.match(rootPage, /Looking for the terminal/);
  assert.ok(rootPage.includes(`http-equiv="refresh" content="2;url=${expectedRedirectUrl}"`));
  assert.ok(rootPage.includes(`window.location.replace("${expectedRedirectUrl}")`));
}

const response = await worker.fetch(
  new Request("https://supaterm.com/download/latest/appcast.xml?build=1"),
);
assert.equal(response.status, 308);
assert.equal(
  response.headers.get("location"),
  "https://legacy.supaterm.com/download/latest/appcast.xml?build=1",
);

const wwwResponse = await worker.fetch(new Request("https://www.supaterm.com/changelog"));
assert.equal(wwwResponse.status, 308);
assert.equal(wwwResponse.headers.get("location"), "https://legacy.supaterm.com/changelog");

const unknownHostResponse = await worker.fetch(new Request("https://example.com/changelog"));
assert.equal(unknownHostResponse.status, 404);
