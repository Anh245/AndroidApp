import cookie from "cookie";
import { credentials, registerBody } from "./auth.schemas.js";
import { createAuthService, REFRESH_TTL_SECONDS } from "./auth.service.js";

function cookieOptions() {
  const production = process.env.NODE_ENV === "production";
  return {
    httpOnly: true,
    secure: production,
    sameSite: production ? "none" : "lax",
    path: "/api/auth",
  };
}

function readRefreshToken(req) {
  return cookie.parse(req.get("Cookie") || "").refreshToken;
}

export function createAuthController(prisma) {
  const service = createAuthService(prisma);
  return {
    register: async (req, res) => {
      res.status(201).json(await service.register(registerBody.parse(req.body)));
    },
    login: async (req, res) => {
      const result = await service.login(credentials.parse(req.body));
      res.cookie("refreshToken", result.refreshToken, {
        ...cookieOptions(),
        maxAge: REFRESH_TTL_SECONDS * 1000,
      });
      res.json({
        accessToken: result.accessToken,
        accessTokenExpiresAt: result.accessTokenExpiresAt,
        user: result.user,
      });
    },
    refresh: async (req, res) => {
      res.json(await service.refresh(readRefreshToken(req)));
    },
    logout: async (req, res) => {
      await service.logout(readRefreshToken(req));
      res.clearCookie("refreshToken", cookieOptions());
      res.status(204).end();
    },
  };
}
