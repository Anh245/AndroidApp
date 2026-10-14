import { test } from "node:test";
import assert from "node:assert/strict";
import { scryptSync } from "node:crypto";
import { hashPassword, verifyPassword } from "../src/modules/auth/auth.service.js";
import { registerBody } from "../src/modules/auth/auth.schemas.js";

test("new passwords use bcrypt and reject incorrect passwords", async () => {
  const hash = await hashPassword("Password123!");
  assert.match(hash, /^\$2[ab]\$10\$/);
  assert.equal(await verifyPassword("Password123!", hash), true);
  assert.equal(await verifyPassword("wrongPassword", hash), false);
});

test("legacy scrypt accounts still authenticate", async () => {
  const salt = "12".repeat(16);
  const password = "a".repeat(100);
  const hash = `${salt}:${scryptSync(password, salt, 64).toString("hex")}`;
  assert.equal(await verifyPassword(password, hash), true);
  assert.equal(await verifyPassword("wrongPassword", hash), false);
});

test("missing and malformed password hashes fail closed", async () => {
  for (const hash of [undefined, null, "bad", "salt:broken"]) {
    assert.equal(await verifyPassword("Password123!", hash), false);
  }
});

test("bcrypt byte limit prevents truncation, including multibyte passwords", async () => {
  const password = "a".repeat(72);
  const hash = await hashPassword(password);
  assert.equal(await verifyPassword(password + "b", hash), false);
  assert.throws(() => hashPassword("é".repeat(37)), error => error.status === 400);
  assert.equal(registerBody.safeParse({
    name: "Test", email: "test@example.com", password: "é".repeat(37),
  }).success, false);
});
