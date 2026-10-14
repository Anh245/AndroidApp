import { Router } from "express";
import { createCategoryController } from "./category.controller.js";

export function categoryRoutes(prisma) {
  const router = Router();
  const controller = createCategoryController(prisma);
  router.get("/", controller.list);
  router.post("/", controller.create);
  router.put("/:id", controller.update);
  router.delete("/:id", controller.remove);
  return router;
}
