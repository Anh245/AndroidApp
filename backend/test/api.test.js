import { test, before, after } from "node:test";
import { scryptSync } from "node:crypto";
import assert from "node:assert/strict";
import { PGlite } from "@electric-sql/pglite";
import { PGLiteSocketServer } from "@electric-sql/pglite-socket";
import { hashToken } from "../src/modules/auth/auth.service.js";
import request from "supertest";
import { createApp } from "../src/app.js";
import { createPool } from "../scripts/postgres.js";
import { createPrismaClient } from "../src/prisma.js";
import { migrate } from "../scripts/migrate.js";
// Default: PostgreSQL engine compiled to WASM. Optional: a dedicated real PG database.
// Never point TEST_DATABASE_URL at a database containing useful data.
let db,
  databaseUrl,
  engine,
  socketServer,
  prisma,
  app,
  alice,
  bob,
  cats,
  expense,
  income,
  tx,
  budget;
const call = (method, path, token = alice?.accessToken) => {
  const r = request(app)[method](`/api${path}`).set("X-Requested-With", "expense-manager");
  return token ? r.set("Authorization", `Bearer ${token}`) : r;
};
const loginAs = async (email, password = "Password123!") => {
  const response = await call("post", "/auth/login", null).send({ email, password }).expect(200);
  assert.equal(response.body.refreshToken, undefined);
  assert.equal(response.body.refreshTokenExpiresAt, undefined);
  return { ...response.body, cookie: response.headers["set-cookie"][0].split(";")[0] };
};
before(async () => {
  process.env.JWT_ACCESS_SECRET = "test-access-secret-at-least-32-characters";
  if (process.env.TEST_DATABASE_URL) {
    databaseUrl = process.env.TEST_DATABASE_URL;
    db = createPool(databaseUrl);
    const { rows } = await db.query(
      "SELECT tablename FROM pg_tables WHERE schemaname='public'",
    );
    assert.equal(
      rows.length,
      0,
      "Integration tests require a new EMPTY database",
    );
    await migrate(db);
  } else {
    engine = new PGlite();
    // PGlite socket does not apply connection startup timezone options.
    await engine.exec("SET TIME ZONE 'UTC'");
    socketServer = new PGLiteSocketServer({
      db: engine,
      port: 0,
      host: "127.0.0.1",
      maxConnections: 10,
    });
    await socketServer.start();
    databaseUrl = `postgresql://postgres:postgres@${socketServer.getServerConn()}/postgres`;
    db = createPool(databaseUrl);
    await migrate(db);
  }
  prisma = createPrismaClient(databaseUrl);
  await prisma.$connect();
  await prisma.$queryRaw`SELECT 1`;
  app = createApp(prisma);
});
after(async () => {
  if (prisma) await prisma.$disconnect();
  if (db) await db.end();
  if (socketServer) await socketServer.stop();
  if (engine) await engine.close();
});
test("authentication, finance workflows and account isolation", async (t) => {
  await t.test("private routes require login", async () => {
    await call("get", "/categories", null).expect(401);
  });
  await t.test(
    "register creates account and categories; login creates a cookie session",
    async () => {
      for (const [name, email] of [["Nguyễn An", "alice@example.com"], ["Trần Bình", "bob@example.com"]]) {
        const registered = await call("post", "/auth/register", null)
          .send({ name, email, password: "Password123!" }).expect(201);
        assert.equal(registered.body.accessToken, undefined);
        assert.equal(registered.headers["set-cookie"], undefined);
      }
      assert.equal(await prisma.session.count(), 0);
      alice = await loginAs("alice@example.com");
      bob = await loginAs("bob@example.com");
      cats = (await call("get", "/categories").expect(200)).body;
      assert.equal(cats.length, 8);
      expense = cats.find((c) => c.kind === "expense");
      income = cats.find((c) => c.kind === "income");
      assert.equal(
        (await call("get", "/auth/me").expect(200)).body.email,
        "alice@example.com",
      );
      const user = (
        await db.query("SELECT password_hash FROM users WHERE id=$1", [
          alice.user.id,
        ])
      ).rows[0];
      assert.notEqual(user.password_hash, "Password123!");
    },
  );
  await t.test(
    "reject duplicate registration and bad credentials",
    async () => {
      await call("post", "/auth/register", null)
        .send({
          name: "Other",
          email: "ALICE@example.com",
          password: "Password123!",
        })
        .expect(409);
      await call("post", "/auth/login", null)
        .send({ email: "alice@example.com", password: "wrongPassword" })
        .expect(401);
      await call("post", "/auth/login", null)
        .send({ email: "alice@example.com", password: "Password123!" })
        .expect(200);
    },
  );
  await t.test("unknown accounts return 401 and legacy accounts can log in", async () => {
    await call("post", "/auth/login", null)
      .send({ email: "missing@example.com", password: "Password123!" })
      .expect(401);
    const salt = "12".repeat(16);
    const password = "legacy-password-123";
    const passwordHash = `${salt}:${scryptSync(password, salt, 64).toString("hex")}`;
    const legacy = await prisma.user.create({
      data: { name: "Legacy", email: "legacy@example.com", passwordHash },
    });
    const login = await call("post", "/auth/login", null)
      .send({ email: legacy.email, password }).expect(200);
    await call("get", "/users/me", login.body.accessToken).expect(200);
  });
  await t.test("profile reads current database values without password or session details", async () => {
    await prisma.user.update({ where: { id: alice.user.id }, data: { name: "Updated name" } });
    const profile = (await call("get", "/users/me").expect(200)).body;
    assert.deepEqual(profile, { ...alice.user, name: "Updated name" });
    assert.deepEqual((await call("get", "/auth/me").expect(200)).body, profile);
  });
  await t.test("cookie refresh returns only access credentials and keeps fixed session expiry", async () => {
    const login = await loginAs("alice@example.com");
    const rawToken = login.cookie.split("=")[1];
    assert.match(rawToken, /^[a-f0-9]{128}$/);
    const before = await prisma.session.findUnique({ where: { tokenHash: hashToken(rawToken) } });
    assert.ok(before);
    assert.ok(Math.abs(before.expiresAt.valueOf() - Date.now() - 14 * 86400000) < 5000);
    await call("post", "/auth/refresh", null).send({ refreshToken: rawToken }).expect(401);
    await call("post", "/auth/refresh", null).set("Cookie", "refreshToken=unknown").expect(401);
    await call("get", "/users/me", rawToken).expect(401);
    const responses = await Promise.all([1, 2].map(() => call("post", "/auth/refresh", null).set("Cookie", login.cookie).expect(200)));
    for (const response of responses) {
      assert.equal(response.body.refreshToken, undefined);
      assert.equal(response.headers["set-cookie"], undefined);
      assert.deepEqual(Object.keys(response.body).sort(), ["accessToken", "accessTokenExpiresAt"]);
      await call("get", "/users/me", response.body.accessToken).expect(200);
    }
    assert.deepEqual(await prisma.session.findUnique({ where: { tokenHash: hashToken(rawToken) } }), before);
    const logout = await call("post", "/auth/logout", null).set("Cookie", login.cookie).expect(204);
    assert.match(logout.headers["set-cookie"][0], /refreshToken=;/);
    assert.match(logout.headers["set-cookie"][0], /Path=\/api\/auth/);
    assert.equal(await prisma.session.findUnique({ where: { tokenHash: hashToken(rawToken) } }), null);
    await call("post", "/auth/refresh", null).set("Cookie", login.cookie).expect(401);
    await call("get", "/users/me", responses[0].body.accessToken).expect(401);
    await call("get", "/users/me").expect(200);
    await call("post", "/auth/logout", null).expect(204);
  });
  await t.test("cookie flags, credentialed CORS and cross-site protection", async () => {
    const response = await call("post", "/auth/login", null)
      .set("Origin", "http://localhost:5173")
      .send({ email: "alice@example.com", password: "Password123!" }).expect(200);
    assert.equal(response.headers["access-control-allow-credentials"], "true");
    assert.equal(response.headers["access-control-allow-origin"], "http://localhost:5173");
    assert.match(response.headers["set-cookie"][0], /HttpOnly/);
    assert.match(response.headers["set-cookie"][0], /Max-Age=1209600/);
    await request(app).post("/api/auth/refresh").set("Cookie", alice.cookie).expect(403);
    await call("post", "/auth/logout", null).set("Cookie", alice.cookie)
      .set("Origin", "https://untrusted.example").expect(403);
    await call("get", "/users/me").expect(200);
    const previous = process.env.NODE_ENV;
    try {
      process.env.NODE_ENV = "production";
      const production = await call("post", "/auth/login", null)
        .send({ email: "alice@example.com", password: "Password123!" }).expect(200);
      assert.match(production.headers["set-cookie"][0], /; Secure/);
      assert.match(production.headers["set-cookie"][0], /SameSite=None/);
      const cleared = await call("post", "/auth/logout", null)
        .set("Cookie", production.headers["set-cookie"][0].split(";")[0]).expect(204);
      assert.match(cleared.headers["set-cookie"][0], /; Secure/);
      assert.match(cleared.headers["set-cookie"][0], /SameSite=None/);
    } finally {
      if (previous === undefined) delete process.env.NODE_ENV;
      else process.env.NODE_ENV = previous;
    }
  });
  const body = () => ({
    categoryId: expense.id,
    kind: "expense",
    amount: 65000,
    occurredOn: "2026-10-12",
    note: "Ăn trưa",
  });
  await t.test(
    "reject wrong category owner/type, negative/fractional amounts and invalid dates",
    async () => {
      const foreign = (await call("get", "/categories", bob.accessToken)).body[0];
      for (const invalid of [
        { ...body(), amount: 0 },
        { ...body(), amount: -1 },
        { ...body(), amount: 1.5 },
        { ...body(), amount: 1e13 },
        { ...body(), occurredOn: "2026-02-30" },
        { ...body(), categoryId: income.id },
        { ...body(), categoryId: foreign.id },
        { ...body(), userId: bob.user.id },
      ])
        await call("post", "/transactions").send(invalid).expect(400);
    },
  );
  await t.test(
    "create income/expenses; month boundary and statistics are exact",
    async () => {
      tx = (await call("post", "/transactions").send(body()).expect(201)).body;
      await call("post", "/transactions")
        .send({
          ...body(),
          categoryId: income.id,
          kind: "income",
          amount: 1000000,
        })
        .expect(201);
      await call("post", "/transactions")
        .send({ ...body(), amount: 35000, occurredOn: "2026-10-31" })
        .expect(201);
      await call("post", "/transactions")
        .send({ ...body(), amount: 999999, occurredOn: "2026-11-01" })
        .expect(201);
      const s = (
        await call("get", "/reports/summary?month=2026-10").expect(200)
      ).body;
      assert.equal(s.income, "1000000");
      assert.equal(s.expense, "100000");
      assert.equal(s.balance, "900000");
      assert.equal(s.count, 3);
      assert.equal(s.trend.length, 6);
      assert.equal(s.byCategory[0].amount, "100000");
    },
  );
  await t.test("pagination, literal search and Vietnamese note", async () => {
    const data = (
      await call("get", "/transactions?month=2026-10&limit=1&page=1").expect(
        200,
      )
    ).body;
    assert.equal(data.total, 3);
    assert.equal(data.items.length, 1);
    assert.equal(data.items[0].occurredOn, "2026-10-31");
    assert.equal(
      (
        await call("get", "/transactions?month=2026-10&kind=expense").expect(
          200,
        )
      ).body.total,
      2,
    );
    assert.equal(
      (await call("get", "/transactions?search=%27%20OR%201%3D1--").expect(200))
        .body.total,
      0,
    );
    for (const search of ["%", "_", "\\"]) {
      const result = await call("get", `/transactions?search=${encodeURIComponent(search)}`).expect(200);
      assert.equal(result.body.total, 0, `search must treat ${search} literally`);
    }
    const special = (await call("post", "/transactions")
      .send({ ...body(), note: "Discount 10%_path\\file" }).expect(201)).body;
    for (const search of ["%", "_", "\\"]) {
      const result = await call("get", `/transactions?search=${encodeURIComponent(search)}`).expect(200);
      assert.equal(result.body.total, 1);
      assert.equal(result.body.items[0].id, special.id);
    }
    await call("delete", `/transactions/${special.id}`).expect(204);
    await call("get", "/transactions?limit=-1").expect(400);
  });
  await t.test(
    "another user cannot list, update or delete private data",
    async () => {
      assert.equal(
        (await call("get", "/transactions", bob.accessToken)).body.total,
        0,
      );
      assert.equal(
        (await call("get", "/reports/summary?month=2026-10", bob.accessToken)).body
          .expense,
        "0",
      );
      await call("delete", `/transactions/${tx.id}`, bob.accessToken).expect(404);
      const foreignExpense = (
        await call("get", "/categories", bob.accessToken)
      ).body.find((c) => c.kind === "expense");
      await call("put", `/transactions/${tx.id}`, bob.accessToken)
        .send({ ...body(), categoryId: foreignExpense.id })
        .expect(404);
      await call("put", `/categories/${expense.id}`, bob.accessToken)
        .send({ name: "Hacked", kind: "expense" })
        .expect(404);
    },
  );
  await t.test(
    "upsert budget, spent calculation and category delete restriction",
    async () => {
      budget = (
        await call("put", "/budgets")
          .send({ categoryId: expense.id, month: "2026-10", amount: 80000 })
          .expect(200)
      ).body;
      let b = (await call("get", "/budgets?month=2026-10").expect(200)).body[0];
      assert.equal(b.spent, "100000");
      assert.equal(b.amount, "80000");
      await call("put", "/budgets")
        .send({ categoryId: expense.id, month: "2026-10", amount: 200000 })
        .expect(200);
      const list = (await call("get", "/budgets?month=2026-10").expect(200))
        .body;
      assert.equal(list.length, 1);
      assert.equal(list[0].id, budget.id);
      assert.equal(list[0].amount, "200000");
      await call("put", "/budgets")
        .send({ categoryId: income.id, month: "2026-10", amount: 100 })
        .expect(400);
      await call("delete", `/categories/${expense.id}`).expect(409);
      await call("delete", `/budgets/${budget.id}`, bob.accessToken).expect(404);
      assert.deepEqual(
        (await call("get", "/budgets?month=2026-10", bob.accessToken)).body,
        [],
      );
    },
  );
  await t.test(
    "edits and deletes update totals; empty months return zero",
    async () => {
      await call("put", `/transactions/${tx.id}`)
        .send({ ...body(), amount: 100000 })
        .expect(200);
      assert.equal(
        (await call("get", "/reports/summary?month=2026-10")).body.expense,
        "135000",
      );
      await call("delete", `/transactions/${tx.id}`).expect(204);
      assert.equal(
        (await call("get", "/budgets?month=2026-10")).body[0].spent,
        "35000",
      );
      await call("delete", `/budgets/${budget.id}`).expect(204);
      assert.equal(
        (await call("get", "/reports/summary?month=2025-01")).body.balance,
        "0",
      );
    },
  );
  await t.test("category CRUD and uniqueness", async () => {
    const c = (
      await call("post", "/categories")
        .send({ name: "Học tập", kind: "expense" })
        .expect(201)
    ).body;
    await call("post", "/categories")
      .send({ name: "học tập", kind: "expense" })
      .expect(409);
    await call("put", `/categories/${c.id}`)
      .send({ name: "Sách", kind: "expense", color: "#3B82F6" })
      .expect(200);
    await call("delete", `/categories/${c.id}`).expect(204);
  });
  await t.test("expired and revoked sessions cannot be reused", async () => {
    await db.query(
      "UPDATE sessions SET expires_at=now()-interval '1 second' WHERE user_id=$1",
      [bob.user.id],
    );
    await call("get", "/auth/me", bob.accessToken).expect(401);
    await call("post", "/auth/logout").set("Cookie", alice.cookie).expect(204);
    await call("get", "/auth/me").expect(401);
    await call("post", "/auth/refresh", null).set("Cookie", alice.cookie).expect(401);
    await call("post", "/auth/refresh", null).set("Cookie", bob.cookie).expect(401);
    await call("post", "/auth/logout", null).set("Cookie", alice.cookie).expect(204);
  });
});
