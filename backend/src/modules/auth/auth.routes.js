import { createUserController } from "../users/user.controller.js";
import { Router } from "express";
import { rateLimit } from "express-rate-limit";
import { authenticate } from "../../middleware/authenticate.js";
import { createAuthController } from "./auth.controller.js";

export function authRoutes(prisma) {
  const router = Router();
  const controller = createAuthController(prisma);
  const limiter = rateLimit({
    windowMs: 15 * 60 * 1000,
    limit: 30,
    standardHeaders: "draft-8",
    legacyHeaders: false,
    message: { message: "Thử đăng nhập quá nhiều lần. Vui lòng chờ 15 phút." },
  });
  const refreshLimiter = rateLimit({
    windowMs: 15 * 60 * 1000,
    limit: 30,
    standardHeaders: "draft-8",
    legacyHeaders: false,
    message: { message: "Thử làm mới phiên quá nhiều lần. Vui lòng chờ." },
  });
  router.use((_req, res, next) => {
    res.set("Cache-Control", "no-store");
    next();
  });
  router.post("/register", limiter, controller.register);
  router.post("/login", limiter, controller.login);
  router.post("/refresh", refreshLimiter, controller.refresh);
  router.get("/me", authenticate(prisma), createUserController(prisma).me);
  router.post("/logout", controller.logout);
  return router;
}
