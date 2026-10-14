function monthDate(month) {
  return new Date(`${month}-01T00:00:00.000Z`);
}

function nextMonthDate(month) {
  const [year, monthNumber] = month.split("-").map(Number);
  return new Date(Date.UTC(year, monthNumber, 1));
}

export async function listBudgets(prisma, userId, month) {
  const start = monthDate(month);
  const [budgets, spentByCategory] = await prisma.$transaction([
    prisma.budget.findMany({
      where: { userId, month: start },
      orderBy: { category: { name: "asc" } },
      select: {
        id: true,
        categoryId: true,
        month: true,
        amount: true,
        category: { select: { name: true, color: true } },
      },
    }),
    prisma.transaction.groupBy({
      by: ["categoryId"],
      where: {
        userId,
        kind: "expense",
        occurredOn: { gte: start, lt: nextMonthDate(month) },
      },
      _sum: { amount: true },
    }),
  ]);
  const spent = new Map(
    spentByCategory.map((item) => [
      item.categoryId,
      item._sum.amount?.toString() ?? "0",
    ]),
  );
  return budgets.map((budget) => ({
    id: budget.id,
    categoryId: budget.categoryId,
    categoryName: budget.category.name,
    color: budget.category.color,
    month: budget.month.toISOString().slice(0, 7),
    amount: budget.amount.toString(),
    spent: spent.get(budget.categoryId) ?? "0",
  }));
}

export function upsertBudget(prisma, userId, body) {
  const month = monthDate(body.month);
  return prisma.budget.upsert({
    where: {
      userId_categoryId_month: {
        userId,
        categoryId: body.categoryId,
        month,
      },
    },
    create: {
      userId,
      categoryId: body.categoryId,
      month,
      amount: body.amount,
    },
    update: { amount: body.amount },
    select: { id: true },
  });
}

export async function deleteBudget(prisma, userId, id) {
  const result = await prisma.budget.deleteMany({ where: { id, userId } });
  return result.count ? { id } : null;
}
