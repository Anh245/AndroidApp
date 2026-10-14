import { month } from "./report.schemas.js";
import { createReportService } from "./report.service.js";

export function createReportController(prisma) {
  const service = createReportService(prisma);
  return {
    summary: async (req, res) =>
      res.json(
        await service.summary(req.user.id, month.parse(req.query.month)),
      ),
  };
}
