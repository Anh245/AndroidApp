import { ApiError } from "../../validation.js";
import { createCategoryService } from "../categories/category.service.js";
import {
  createTransaction,
  deleteTransaction,
  listTransactions,
  updateTransaction,
} from "./transaction.repository.js";

export function createTransactionService(prisma) {
  const categories = createCategoryService(prisma);
  return {
    async list(userId, filters) {
      return {
        ...(await listTransactions(prisma, userId, filters)),
        page: filters.page,
        limit: filters.limit,
      };
    },
    async create(userId, body) {
      await categories.assertMatchingKind(userId, body.categoryId, body.kind);
      return createTransaction(prisma, userId, body);
    },
    async update(userId, id, body) {
      await categories.assertMatchingKind(userId, body.categoryId, body.kind);
      const transaction = await updateTransaction(prisma, userId, id, body);
      if (!transaction) throw new ApiError(404, "Không tìm thấy dữ liệu.");
      return transaction;
    },
    async remove(userId, id) {
      const transaction = await deleteTransaction(prisma, userId, id);
      if (!transaction) throw new ApiError(404, "Không tìm thấy dữ liệu.");
    },
  };
}
