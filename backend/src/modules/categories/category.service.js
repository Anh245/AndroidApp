import { ApiError } from "../../validation.js";
import {
  countCategoryUsage,
  createCategory,
  deleteCategory,
  findCategory,
  findMatchingCategory,
  listCategories,
  updateCategory,
} from "./category.repository.js";

const DUPLICATE_MESSAGE = "Tên danh mục đã tồn tại trong nhóm thu/chi này.";

// Đổi lỗi trùng khóa duy nhất (Prisma P2002 / PostgreSQL 23505) thành thông báo
// đúng ngữ cảnh danh mục thay vì thông báo chung nhắc đến email.
async function mapDuplicate(promise) {
  try {
    return await promise;
  } catch (err) {
    if (err?.code === "P2002" || err?.code === "23505")
      throw new ApiError(409, DUPLICATE_MESSAGE);
    throw err;
  }
}

export function createCategoryService(prisma) {
  return {
    list: (userId) => listCategories(prisma, userId),
    create: (userId, body) =>
      mapDuplicate(createCategory(prisma, userId, body)),
    async update(userId, id, body) {
      const current = await findCategory(prisma, userId, id);
      if (!current) throw new ApiError(404, "Không tìm thấy dữ liệu.");
      if (
        current.kind !== body.kind &&
        (await countCategoryUsage(prisma, userId, id)) > 0
      )
        throw new ApiError(
          409,
          "Danh mục đã có giao dịch hoặc ngân sách nên không thể đổi loại thu/chi. Bạn chỉ đổi được tên và màu.",
        );
      const category = await mapDuplicate(
        updateCategory(prisma, userId, id, body),
      );
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
