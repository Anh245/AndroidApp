import { test, before } from "node:test";
import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import jwt from "jsonwebtoken";
import { createTokenPair, verifyAccessToken, validateTokenConfig } from "../src/modules/auth/auth.service.js";

before(() => {
  process.env.JWT_ACCESS_SECRET = "test-access-secret-at-least-32-characters";
});
const claims = () => ({ sub: randomUUID(), sid: randomUUID(), jti: randomUUID(), tokenUse: "access" });
const sign = (payload, options = {}) => jwt.sign(payload, process.env.JWT_ACCESS_SECRET, {
  algorithm: "HS256", audience: "expense-manager-client", issuer: "expense-manager-api", expiresIn: 900, ...options,
});
const unauthorized = (run) => assert.throws(run, error => error.status === 401);

test("token pair has distinct purposes, minimal claims and exact expiration metadata", () => {
  const user = { id: randomUUID(), name: "Name", email: "private@example.com" };
  const pair = createTokenPair(user, randomUUID());
  const access = verifyAccessToken(pair.accessToken);
  assert.match(pair.refreshToken, /^[a-f0-9]{128}$/);
  assert.equal(jwt.decode(pair.refreshToken), null);
  assert.equal(access.sub, user.id);
  assert.equal(access.exp - access.iat, 900);
  assert.equal(pair.accessTokenExpiresAt.valueOf(), access.exp * 1000);
  assert.ok(Math.abs(pair.refreshTokenExpiresAt.valueOf() - Date.now() - 1209600000) < 1000);
  assert.notEqual(pair.refreshToken, createTokenPair(user, access.sid).refreshToken);
  assert.equal(access.email, undefined);
  assert.equal(access.name, undefined);
  unauthorized(() => verifyAccessToken(pair.refreshToken));
});

test("reject expired, tampered, wrong audience/issuer/algorithm and malformed claims", () => {
  for (const token of [
    sign(claims(), { expiresIn: -1 }),
    sign(claims(), { audience: "other" }),
    sign(claims(), { issuer: "other" }),
    sign(claims(), { algorithm: "HS384" }),
    sign({ ...claims(), tokenUse: "refresh" }),
    sign({ ...claims(), sub: "invalid-uuid" }),
    sign({ ...claims(), sid: "invalid-uuid" }),
    sign({ ...claims(), jti: undefined }),
    jwt.sign(claims(), process.env.JWT_ACCESS_SECRET, { audience: "expense-manager-client", issuer: "expense-manager-api" }),
    sign(claims()) + "tampered",
    "legacy-opaque-token",
  ]) unauthorized(() => verifyAccessToken(token));
});

test("only the access signing secret is required", () => {
  delete process.env.JWT_REFRESH_SECRET;
  const original = process.env.JWT_ACCESS_SECRET;
  assert.doesNotThrow(validateTokenConfig);
  try {
    for (const value of ["", "short"]) {
      process.env.JWT_ACCESS_SECRET = value;
      assert.throws(validateTokenConfig);
    }
  } finally { process.env.JWT_ACCESS_SECRET = original; }
});
