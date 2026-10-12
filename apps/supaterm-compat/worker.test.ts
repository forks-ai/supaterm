import assert from "node:assert/strict";

import worker from "./worker.ts";

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
