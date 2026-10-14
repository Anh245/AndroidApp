import { Router } from "express";
import { createBudgetController } from "./budget.controller.js";

export function budgetRoutes(prisma) {
  const router = Router();
  const controller = createBudgetController(prisma);
  router.get("/", controller.list);
  router.put("/", controller.upsert);
  router.delete("/:id", controller.remove);
  return router;
}
