export function insertSession(prisma, data) {
  return prisma.session.create({ data });
}

export function findSessionById(prisma, sessionId) {
  return prisma.session.findUnique({ where: { sessionId } });
}

export function findSessionByTokenHash(prisma, tokenHash) {
  return prisma.session.findUnique({ where: { tokenHash } });
}

export function deleteSessionByTokenHash(prisma, tokenHash) {
  return prisma.session.deleteMany({ where: { tokenHash } });
}
