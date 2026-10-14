import {
  createHash,
  randomBytes,
  randomUUID,
  scrypt as rawScrypt,
  timingSafeEqual,
} from "node:crypto";
import { promisify } from "node:util";
import bcrypt from "bcrypt";
import jwt from "jsonwebtoken";
import { accessTokenClaims } from "./auth.schemas.js";
import { ApiError } from "../../validation.js";
import {
  findSessionById,
  findSessionByTokenHash,
  deleteSessionByTokenHash,
  insertSession,
} from "./auth.repository.js";
import {
  findUserByEmail,
  findUserById,
  insertUser,
} from "../users/user.repository.js";
import { insertDefaultCategories } from "../categories/category.repository.js";

// Password hashing and verification.

const BCRYPT_ROUNDS = 10;

const scrypt = promisify(rawScrypt);
const DUMMY_HASH = bcrypt.hashSync(
  "dummy-password-not-an-account",
  BCRYPT_ROUNDS,
);

export function hashPassword(password) {
  if (Buffer.byteLength(password, "utf8") > 72)
    throw new ApiError(400, "Mật khẩu không được vượt quá 72 byte UTF-8.");
  return bcrypt.hash(password, BCRYPT_ROUNDS);
}

export async function verifyPassword(password, encoded) {
  if (typeof encoded === "string" && /^\$2[ab]\$/.test(encoded)) {
    const valid = await bcrypt.compare(password, encoded);
    return Buffer.byteLength(password, "utf8") <= 72 && valid;
  }
  if (
    typeof encoded === "string" &&
    /^[a-f0-9]{32}:[a-f0-9]{128}$/i.test(encoded)
  ) {
    const [salt, hex] = encoded.split(":");
    const key = await scrypt(password, salt, 64);
    return timingSafeEqual(Buffer.from(hex, "hex"), key);
  }
  await bcrypt.compare(password, DUMMY_HASH);
  return false;
}

// JWT access tokens and database-backed opaque refresh tokens.
const ACCESS_TTL_SECONDS = 15 * 60;
export const REFRESH_TTL_SECONDS = 14 * 24 * 60 * 60;
const JWT_ISSUER = "expense-manager-api";
const JWT_AUDIENCE = "expense-manager-client";

function secretFor(name) {
  const secret = process.env[name];
  if (!secret || secret.length < 32)
    throw new Error(`${name} must be set to at least 32 characters.`);
  return secret;
}

export function validateTokenConfig() {
  secretFor("JWT_ACCESS_SECRET");
}

function signToken(tokenUse, secretName, userId, sessionId, expiresIn) {
  return jwt.sign({ tokenUse, sid: sessionId }, secretFor(secretName), {
    algorithm: "HS256",
    audience: JWT_AUDIENCE,
    issuer: JWT_ISSUER,
    expiresIn,
    jwtid: randomUUID(),
    subject: userId,
  });
}

export function verifyAccessToken(token) {
  const secret = secretFor("JWT_ACCESS_SECRET");
  try {
    // jwt.verify checks the signature, expiry, algorithm, issuer and audience.
    const payload = jwt.verify(token, secret, {
      algorithms: ["HS256"],
      audience: JWT_AUDIENCE,
      issuer: JWT_ISSUER,
    });
    accessTokenClaims.parse(payload);
    return payload;
  } catch {
    throw new ApiError(401, "Token không hợp lệ hoặc đã hết hạn.");
  }
}

export const hashToken = (token) =>
  createHash("sha256").update(token).digest("hex");

function createAccessToken(user, sessionId) {
  const accessToken = signToken(
    "access", "JWT_ACCESS_SECRET", user.id, sessionId, ACCESS_TTL_SECONDS,
  );
  return {
    accessToken,
    accessTokenExpiresAt: new Date(jwt.decode(accessToken).exp * 1000),
  };
}

// Internal service result: the controller sends refreshToken only as a cookie.
export function createTokenPair(user, sessionId) {
  return {
    ...createAccessToken(user, sessionId),
    refreshToken: randomBytes(64).toString("hex"),
    refreshTokenExpiresAt: new Date(Date.now() + REFRESH_TTL_SECONDS * 1000),
  };
}

// Authentication workflows and session lifecycle.
async function createSession(prisma, user, client = prisma) {
  const sessionId = randomUUID();
  const tokens = createTokenPair(user, sessionId);
  await insertSession(client, {
    tokenHash: hashToken(tokens.refreshToken),
    sessionId,
    userId: user.id,
    expiresAt: tokens.refreshTokenExpiresAt,
  });
  return {
    ...tokens,
    user: { id: user.id, name: user.name, email: user.email },
  };
}

export function createAuthService(prisma) {
  return {
    async register(body) {
      const passwordHash = await hashPassword(body.password);
      return prisma.$transaction(async (client) => {
        const user = await insertUser(client, {
          name: body.name,
          email: body.email,
          passwordHash,
        });
        await insertDefaultCategories(client, user.id);
        return { message: "Đăng ký thành công." };
      });
    },

    async login(body) {
      const user = await findUserByEmail(prisma, body.email);
      const valid = await verifyPassword(body.password, user?.passwordHash);
      if (!user || !valid)
        throw new ApiError(401, "Email hoặc mật khẩu chưa đúng.");
      return createSession(prisma, user);
    },

    async authenticateAccess(token) {
      const claims = verifyAccessToken(token);
      const session = await findSessionById(prisma, claims.sid);
      if (
        !session ||
        session.userId !== claims.sub ||
        session.revokedAt ||
        session.expiresAt <= new Date()
      )
        throw new ApiError(
          401,
          "Phiên đăng nhập hết hạn. Vui lòng đăng nhập lại.",
        );
      return { id: claims.sub, sessionId: claims.sid };
    },

    async refresh(refreshToken) {
      if (!refreshToken) throw new ApiError(401, "Không có refresh token.");
      const currentTokenHash = hashToken(refreshToken);
      const session = await findSessionByTokenHash(prisma, currentTokenHash);
      if (!session || session.revokedAt || session.expiresAt <= new Date())
        throw new ApiError(
          401,
          "Phiên đăng nhập hết hạn. Vui lòng đăng nhập lại.",
        );

      const user = await findUserById(prisma, session.userId);
      if (!user)
        throw new ApiError(
          401,
          "Phiên đăng nhập hết hạn. Vui lòng đăng nhập lại.",
        );
      return createAccessToken(user, session.sessionId);
    },

    async logout(refreshToken) {
      if (refreshToken) await deleteSessionByTokenHash(prisma, hashToken(refreshToken));
    },
  };
}
