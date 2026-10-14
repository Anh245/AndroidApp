import "dotenv/config";
import { PrismaPg } from "@prisma/adapter-pg";
import { PrismaClient } from "@prisma/client";

export function createPrismaClient(
  connectionString = process.env.DATABASE_URL,
) {
  if (!connectionString)
    throw new Error("Missing DATABASE_URL. Copy .env.example to .env.");
  const adapter = new PrismaPg({
    connectionString,
    // Prisma serializes DateTime parameters in UTC without an offset.
    options: "-c timezone=UTC",
    max: 10,
    connectionTimeoutMillis: 5000,
  });
  return new PrismaClient({ adapter });
}
