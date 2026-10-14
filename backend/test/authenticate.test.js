import { before, test } from "node:test";
import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { authenticate } from "../src/middleware/authenticate.js";
import { createTokenPair } from "../src/modules/auth/auth.service.js";

before(() => {
  process.env.JWT_ACCESS_SECRET = "test-access-secret-at-least-32-characters";
});
const requestWith = (header) => ({ get: () => header });
const unauthorized = (error) => error.status === 401;

test("missing or malformed authorization is rejected before querying Prisma", async () => {
  const middleware = authenticate({});
  for (const header of [undefined, "", "Bearer", "Basic abc", "Bearer a b", "Bearer\tabc"]) {
    await assert.rejects(middleware(requestWith(header), {}, () => assert.fail("next called")), unauthorized);
  }
});

test("valid access token sets identity and calls next once", async () => {
  const user = { id: randomUUID() };
  const sessionId = randomUUID();
  const { accessToken } = createTokenPair(user, sessionId);
  const prisma = { session: { findUnique: async ({ where }) => {
    assert.equal(where.sessionId, sessionId);
    return { userId: user.id, revokedAt: null, expiresAt: new Date(Date.now() + 60000) };
  } } };
  const req = requestWith(`bearer ${accessToken}`);
  let nextCalls = 0;
  await authenticate(prisma)(req, {}, () => nextCalls++);
  assert.deepEqual(req.user, { id: user.id, sessionId });
  assert.equal(nextCalls, 1);
});

test("refresh tokens and deleted sessions cannot authenticate", async () => {
  const pair = createTokenPair({ id: randomUUID() }, randomUUID());
  const middleware = authenticate({ session: { findUnique: async () => null } });
  for (const token of [pair.refreshToken, pair.accessToken, "invalid-token"]) {
    const req = requestWith(`Bearer ${token}`);
    await assert.rejects(middleware(req, {}, () => assert.fail("next called")), unauthorized);
    assert.equal(req.user, undefined);
  }
});

test("Prisma errors propagate to Express error handling instead of calling next", async () => {
  const { accessToken } = createTokenPair({ id: randomUUID() }, randomUUID());
  const databaseError = new Error("Database unavailable");
  const middleware = authenticate({ session: { findUnique: async () => { throw databaseError; } } });
  await assert.rejects(middleware(requestWith(`Bearer ${accessToken}`), {}, () => assert.fail("next called")),
    error => error === databaseError);
});
