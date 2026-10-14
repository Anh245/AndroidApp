import { readFile, readdir } from "node:fs/promises";
import { fileURLToPath, pathToFileURL } from "node:url";
import { createHash } from "node:crypto";
import { createPool, transaction } from "./postgres.js";
export async function migrate(db) {
  const directory = new URL("../migrations/", import.meta.url);
  await transaction(db, async (client) => {
    await client.query("SELECT pg_advisory_xact_lock(82651012)");
    await client.query(
      "CREATE TABLE IF NOT EXISTS schema_migrations(name TEXT PRIMARY KEY,checksum TEXT NOT NULL,applied_at TIMESTAMPTZ NOT NULL DEFAULT now())",
    );
    for (const name of (await readdir(directory))
      .filter((n) => n.endsWith(".sql"))
      .sort()) {
      const sql = await readFile(new URL(name, directory), "utf8");
      const checksum = createHash("sha256").update(sql).digest("hex");
      const { rows } = await client.query(
        "SELECT checksum FROM schema_migrations WHERE name=$1",
        [name],
      );
      if (rows.length) {
        if (rows[0].checksum !== checksum)
          throw new Error(`Migration modified: ${name}`);
        continue;
      }
      await client.query(sql);
      await client.query(
        "INSERT INTO schema_migrations(name,checksum) VALUES($1,$2)",
        [name, checksum],
      );
      console.log(`Applied ${name}`);
    }
  });
}
if (
  process.argv[1] &&
  pathToFileURL(process.argv[1]).href === import.meta.url
) {
  const db = createPool();
  try {
    await migrate(db);
  } finally {
    await db.end();
  }
}
