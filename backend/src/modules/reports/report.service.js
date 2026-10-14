import { getMonthlySummary } from "./report.repository.js";

export function createReportService(prisma) {
  return {
    summary: (userId, month) => getMonthlySummary(prisma, userId, month),
  };
}
