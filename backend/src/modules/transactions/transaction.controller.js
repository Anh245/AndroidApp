import { filters, transactionBody, uuid } from "./transaction.schemas.js";
import { createTransactionService } from "./transaction.service.js";

export function createTransactionController(prisma) {
  const service = createTransactionService(prisma);
  return {
    list: async (req, res) =>
      res.json(await service.list(req.user.id, filters.parse(req.query))),
    create: async (req, res) => {
      const body = transactionBody.parse(req.body);
      res.status(201).json(await service.create(req.user.id, body));
    },
    update: async (req, res) => {
      const id = uuid.parse(req.params.id);
      const body = transactionBody.parse(req.body);
      res.json(await service.update(req.user.id, id, body));
    },
    remove: async (req, res) => {
      await service.remove(req.user.id, uuid.parse(req.params.id));
      res.status(204).end();
    },
  };
}
