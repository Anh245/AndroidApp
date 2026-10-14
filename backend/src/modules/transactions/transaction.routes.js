import { Router } from "express";
import { createTransactionController } from "./transaction.controller.js";

export function transactionRoutes(prisma) {
  const router = Router();
  const controller = createTransactionController(prisma);
  router.get("/", controller.list);
  router.post("/", controller.create);
  router.put("/:id", controller.update);
  router.delete("/:id", controller.remove);
  return router;
}
