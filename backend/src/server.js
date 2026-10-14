import { createPrismaClient } from "./prisma.js";
import { createApp } from "./app.js";

const prisma = createPrismaClient();
await prisma.$queryRaw`SELECT 1`;
const port = Number(process.env.PORT || 3000);
const server = createApp(prisma).listen(port, "0.0.0.0", () => {
  console.log(`Expense API listening on http://localhost:${port}`);
});

for (const signal of ["SIGINT", "SIGTERM"])
  process.on(signal, () =>
    server.close(async () => {
      await prisma.$disconnect();
      process.exit(0);
    }),
  );
