import { ApiError } from "../../validation.js";
import {
  createCategory,
  deleteCategory,
  findMatchingCategory,
  listCategories,
  updateCategory,
} from "./category.repository.js";

export function createCategoryService(prisma) {
  return {
    list: (userId) => listCategories(prisma, userId),
    create: (userId, body) => createCategory(prisma, userId, body),
    async update(userId, id, body) {
      const category = await updateCategory(prisma, userId, id, body);
      if (!category) throw new ApiError(404, "Không tìm thấy dữ liệu.");
      return category;
    },
    async remove(userId, id) {
      const category = await deleteCategory(prisma, userId, id);
      if (!category) throw new ApiError(404, "Không tìm thấy dữ liệu.");
    },
    async assertMatchingKind(userId, categoryId, kind) {
      if (!(await findMatchingCategory(prisma, userId, categoryId, kind)))
        throw new ApiError(
          400,
          "Danh mục không hợp lệ hoặc không cùng loại thu/chi.",
        );
    },
  };
}
