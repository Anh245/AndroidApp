import { Router } from "express";
import { createReportController } from "./report.controller.js";

export function reportRoutes(prisma) {
  const router = Router();
  const controller = createReportController(prisma);
  router.get("/summary", controller.summary);
  return router;
}
