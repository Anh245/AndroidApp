import { createUserService } from "./user.service.js";

export function createUserController(prisma) {
  const service = createUserService(prisma);
  return { me: async (req, res) => res.json(await service.me(req.user.id)) };
}
