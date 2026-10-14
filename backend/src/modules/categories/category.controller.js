import { categoryBody, uuid } from "./category.schemas.js";
import { createCategoryService } from "./category.service.js";

export function createCategoryController(prisma) {
  const service = createCategoryService(prisma);
  return {
    list: async (req, res) => res.json(await service.list(req.user.id)),
    create: async (req, res) => {
      const body = categoryBody.parse(req.body);
      res.status(201).json(await service.create(req.user.id, body));
    },
    update: async (req, res) => {
      const id = uuid.parse(req.params.id);
      const body = categoryBody.parse(req.body);
      res.json(await service.update(req.user.id, id, body));
    },
    remove: async (req, res) => {
      await service.remove(req.user.id, uuid.parse(req.params.id));
      res.status(204).end();
    },
  };
}
