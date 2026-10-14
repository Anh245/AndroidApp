function monthStart(month) {
  return new Date(`${month}-01T00:00:00.000Z`);
}

function nextMonthStart(month) {
  const [year, monthNumber] = month.split("-").map(Number);
  return new Date(Date.UTC(year, monthNumber, 1));
}

function transactionWhere(userId, filters) {
  // Prisma contains uses LIKE: escape wildcards for literal substring search.
  const search = filters.search?.replace(/[\\%_]/g, "\\$&");
  return {
    userId,
    ...(filters.kind ? { kind: filters.kind } : {}),
    ...(filters.month
      ? {
          occurredOn: {
            gte: monthStart(filters.month),
            lt: nextMonthStart(filters.month),
          },
        }
      : {}),
    ...(filters.search
      ? {
          OR: [
            { note: { contains: search, mode: "insensitive" } },
            {
              category: {
                name: { contains: search, mode: "insensitive" },
              },
            },
          ],
        }
      : {}),
  };
}

export async function listTransactions(prisma, userId, filters) {
  const where = transactionWhere(userId, filters);
  const [total, transactions] = await prisma.$transaction([
    prisma.transaction.count({ where }),
    prisma.transaction.findMany({
      where,
      orderBy: [{ occurredOn: "desc" }, { createdAt: "desc" }, { id: "desc" }],
      skip: (filters.page - 1) * filters.limit,
      take: filters.limit,
      select: {
        id: true,
        categoryId: true,
        kind: true,
        amount: true,
        occurredOn: true,
        note: true,
        paymentMethod: true,
        category: { select: { name: true, color: true } },
      },
    }),
  ]);
  return {
    total,
    items: transactions.map((transaction) => ({
      id: transaction.id,
      categoryId: transaction.categoryId,
      kind: transaction.kind,
      amount: transaction.amount.toString(),
      occurredOn: transaction.occurredOn.toISOString().slice(0, 10),
      note: transaction.note,
      paymentMethod: transaction.paymentMethod,
      categoryName: transaction.category.name,
      color: transaction.category.color,
    })),
  };
}

export async function createTransaction(prisma, userId, body) {
  const transaction = await prisma.transaction.create({
    data: {
      userId,
      categoryId: body.categoryId,
      kind: body.kind,
      amount: body.amount,
      occurredOn: new Date(`${body.occurredOn}T00:00:00.000Z`),
      note: body.note,
      paymentMethod: body.paymentMethod,
    },
    select: { id: true },
  });
  return transaction;
}

export async function updateTransaction(prisma, userId, id, body) {
  const result = await prisma.transaction.updateMany({
    where: { id, userId },
    data: {
      categoryId: body.categoryId,
      kind: body.kind,
      amount: body.amount,
      occurredOn: new Date(`${body.occurredOn}T00:00:00.000Z`),
      note: body.note,
      paymentMethod: body.paymentMethod,
    },
  });
  return result.count ? { id } : null;
}

export async function deleteTransaction(prisma, userId, id) {
  const result = await prisma.transaction.deleteMany({ where: { id, userId } });
  return result.count ? { id } : null;
}
