import { Router } from "express";
import { createUserController } from "./user.controller.js";

export function userRoutes(prisma) {
  const router = Router();
  router.get("/me", createUserController(prisma).me);
  return router;
}
