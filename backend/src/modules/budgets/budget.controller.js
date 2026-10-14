import { budgetBody, month, uuid } from "./budget.schemas.js";
import { createBudgetService } from "./budget.service.js";

export function createBudgetController(prisma) {
  const service = createBudgetService(prisma);
  return {
    list: async (req, res) =>
      res.json(await service.list(req.user.id, month.parse(req.query.month))),
    upsert: async (req, res) => {
      const body = budgetBody.parse(req.body);
      res.json(await service.upsert(req.user.id, body));
    },
    remove: async (req, res) => {
      await service.remove(req.user.id, uuid.parse(req.params.id));
      res.status(204).end();
    },
  };
}
