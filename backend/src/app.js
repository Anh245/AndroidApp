import { userRoutes } from "./modules/users/user.routes.js";
import { validateTokenConfig } from "./modules/auth/auth.service.js";
import express from "express";
import helmet from "helmet";
import cors from "cors";
import { rateLimit } from "express-rate-limit";
import { ZodError } from "zod";
import { authRoutes } from "./modules/auth/auth.routes.js";
import { authenticate } from "./middleware/authenticate.js";
import { categoryRoutes } from "./modules/categories/category.routes.js";
import { transactionRoutes } from "./modules/transactions/transaction.routes.js";
import { budgetRoutes } from "./modules/budgets/budget.routes.js";
import { reportRoutes } from "./modules/reports/report.routes.js";
export function createApp(prisma) {
  validateTokenConfig();
  const app = express();
  app.disable("x-powered-by");
  app.use(helmet());
  const origins = (
    process.env.CORS_ORIGINS || "http://localhost:5173,http://127.0.0.1:5173"
  )
    .split(",")
    .map((x) => x.trim());
  app.use(
    cors({
      credentials: true,
      origin: (origin, cb) => cb(null, !origin || origins.includes(origin)),
    }),
  );
  app.use(express.json({ limit: "32kb" }));
  app.use(
    "/api",
    rateLimit({
      windowMs: 60 * 1000,
      limit: 300,
      standardHeaders: "draft-8",
      legacyHeaders: false,
      message: { message: "Quá nhiều yêu cầu. Vui lòng thử lại sau." },
    }),
  );
  app.get("/health", async (_req, res) => {
    await prisma.$queryRaw`SELECT 1`;
    res.json({ status: "ok" });
  });
  // Cookie-authenticated mutations require a custom header (CORS preflight).
  app.use("/api/auth", (req, res, next) => {
    if (
      req.method === "POST" &&
      (req.get("X-Requested-With") !== "expense-manager" ||
        (req.get("Origin") && !origins.includes(req.get("Origin"))))
    )
      return res.status(403).json({ message: "Yêu cầu không được phép." });
    next();
  });
  app.use("/api/auth", authRoutes(prisma));
  app.use("/api", authenticate(prisma));
  app.use("/api/users", userRoutes(prisma));
  app.use("/api/categories", categoryRoutes(prisma));
  app.use("/api/transactions", transactionRoutes(prisma));
  app.use("/api/budgets", budgetRoutes(prisma));
  app.use("/api/reports", reportRoutes(prisma));
  app.use((_req, res) =>
    res.status(404).json({ message: "Đường dẫn không tồn tại." }),
  );
  app.use((err, _req, res, _next) => {
    if (err instanceof ZodError)
      return res.status(400).json({
        message: "Dữ liệu chưa hợp lệ.",
        errors: err.issues.map((i) => ({
          field: i.path.join("."),
          message: i.message,
        })),
      });
    if (err.code === "23505" || err.code === "P2002")
      return res
        .status(409)
        .json({ message: "Email hoặc tên danh mục đã tồn tại." });
    if (
      err.code === "23503" ||
      err.code === "23001" ||
      err.code === "P2003" ||
      err.code === "P2014"
    )
      return res.status(409).json({
        message:
          "Danh mục đã được dùng trong giao dịch/ngân sách, hoặc không còn tồn tại. Hãy kiểm tra dữ liệu liên quan.",
      });
    if (err.code === "23514" || err.code === "P2004")
      return res
        .status(400)
        .json({ message: "Dữ liệu không thỏa mãn ràng buộc." });
    const status = err.status || 500;
    if (status >= 500) console.error("Request failed:", err.message);
    res.status(status).json({
      message:
        status >= 500
          ? "Máy chủ gặp lỗi. Vui lòng thử lại sau."
          : err.type === "entity.parse.failed"
            ? "JSON không hợp lệ."
            : err.message,
    });
  });
  return app;
}
