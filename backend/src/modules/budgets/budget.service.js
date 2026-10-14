import { ApiError } from "../../validation.js";
import { createCategoryService } from "../categories/category.service.js";
import {
  deleteBudget,
  listBudgets,
  upsertBudget,
} from "./budget.repository.js";

export function createBudgetService(prisma) {
  const categories = createCategoryService(prisma);
  return {
    list: (userId, month) => listBudgets(prisma, userId, month),
    async upsert(userId, body) {
      await categories.assertMatchingKind(userId, body.categoryId, "expense");
      return upsertBudget(prisma, userId, body);
    },
    async remove(userId, id) {
      const budget = await deleteBudget(prisma, userId, id);
      if (!budget) throw new ApiError(404, "Không tìm thấy dữ liệu.");
    },
  };
}
