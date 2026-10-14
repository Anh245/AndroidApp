export function insertUser(prisma, data) {
  return prisma.user.create({
    data,
    select: { id: true, name: true, email: true },
  });
}

export function findUserByEmail(prisma, email) {
  return prisma.user.findUnique({ where: { email } });
}

export function findUserById(prisma, id) {
  return prisma.user.findUnique({
    where: { id },
    select: { id: true, name: true, email: true },
  });
}

