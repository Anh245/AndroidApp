const categorySelect = { id: true, name: true, kind: true, color: true };

export function listCategories(prisma, userId) {
  return prisma.category.findMany({
    where: { userId },
    orderBy: [{ kind: "asc" }, { name: "asc" }],
    select: categorySelect,
  });
}

export function createCategory(prisma, userId, body) {
  return prisma.category.create({
    data: { userId, ...body },
    select: categorySelect,
  });
}

export async function updateCategory(prisma, userId, id, body) {
  const result = await prisma.category.updateMany({
    where: { id, userId },
    data: body,
  });
  if (result.count === 0) return null;
  return prisma.category.findFirst({
    where: { id, userId },
    select: categorySelect,
  });
}

export async function deleteCategory(prisma, userId, id) {
  const result = await prisma.category.deleteMany({ where: { id, userId } });
  return result.count ? { id } : null;
}

export function findMatchingCategory(prisma, userId, categoryId, kind) {
  return prisma.category.findFirst({
    where: { id: categoryId, userId, kind },
    select: { id: true },
  });
}

const defaults = [
  ["Ăn uống", "expense", "#F97316"],
  ["Di chuyển", "expense", "#3B82F6"],
  ["Mua sắm", "expense", "#8B5CF6"],
  ["Nhà ở", "expense", "#0F766E"],
  ["Sức khỏe", "expense", "#EF4444"],
  ["Giải trí", "expense", "#EC4899"],
  ["Lương", "income", "#059669"],
  ["Thu nhập khác", "income", "#06B6D4"],
];

export function insertDefaultCategories(prisma, userId) {
  return prisma.category.createMany({
    data: defaults.map(([name, kind, color]) => ({
      userId,
      name,
      kind,
      color,
    })),
  });
}

