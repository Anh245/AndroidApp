import { z } from "zod";

export const credentials = z.object({
  email: z.string().trim().toLowerCase().pipe(z.email().max(254)),
  password: z.string().min(8).max(128),
}).strict();

export const registerBody = credentials.extend({
  name: z.string().trim().min(2).max(80),
  password: z.string().min(8).max(128).refine(
    (value) => Buffer.byteLength(value, "utf8") <= 72,
    "Mật khẩu không được vượt quá 72 byte UTF-8.",
  ),
});

// Claims required by access-token authentication.
export const accessTokenClaims = z.object({
  tokenUse: z.literal("access"),
  sub: z.uuid(),
  sid: z.uuid(),
  jti: z.uuid(),
  exp: z.number().int(),
  iat: z.number().int(),
});
