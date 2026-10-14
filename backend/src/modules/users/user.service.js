import { ApiError } from "../../validation.js";
import { findUserById } from "./user.repository.js";

export function createUserService(prisma) {
  return {
    async me(userId) {
      const user = await findUserById(prisma, userId);
      if (!user) throw new ApiError(401, "Tài khoản không còn tồn tại.");
      return user;
    },
  };
}
