import "dotenv/config";
import pg from "pg";

pg.types.setTypeParser(1082, (value) => value);

export function createPool(url = process.env.DATABASE_URL) {
  if (!url) throw new Error("Missing DATABASE_URL. Copy .env.example to .env.");
  const pool = new pg.Pool({
    connectionString: url,
    max: 10,
    connectionTimeoutMillis: 5000,
  });
  pool.on("error", (err) =>
    console.error("Idle database connection error:", err.message),
  );
  return pool;
}

export async function transaction(pool, callback) {
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    const result = await callback(client);
    await client.query("COMMIT");
    return result;
  } catch (err) {
    await client.query("ROLLBACK");
    throw err;
  } finally {
    client.release();
  }
}