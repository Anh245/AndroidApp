import { ApiError } from "../validation.js";
import { createAuthService } from "../modules/auth/auth.service.js";

export function authenticate(prisma) {
  const service = createAuthService(prisma);

  return async (req, _res, next) => {
    const header = req.get("Authorization") || "";
    const match = /^Bearer +([^\s]+)$/i.exec(header);
    if (!match) throw new ApiError(401, "Vui lòng cung cấp access token hợp lệ.");

    // The service verifies JWT and checks the session through Prisma.
    // Express 5 forwards rejected promises to the shared error middleware.
    req.user = await service.authenticateAccess(match[1]);
    next();
  };
}
