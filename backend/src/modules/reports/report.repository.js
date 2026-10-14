function monthStart(month) {
  return new Date(`${month}-01T00:00:00.000Z`);
}

function nextMonthStart(month) {
  const [year, monthNumber] = month.split("-").map(Number);
  return new Date(Date.UTC(year, monthNumber, 1));
}

export async function getMonthlySummary(prisma, userId, month) {
  const start = monthStart(month);
  const end = nextMonthStart(month);
  const where = { userId, occurredOn: { gte: start, lt: end } };
  const [totals, categoryTotals, categories, trend] = await prisma.$transaction(
    [
      prisma.transaction.groupBy({
        by: ["kind"],
        where,
        _sum: { amount: true },
        _count: { _all: true },
      }),
      prisma.transaction.groupBy({
        by: ["categoryId"],
        where: { ...where, kind: "expense" },
        _sum: { amount: true },
      }),
      prisma.category.findMany({
        where: { userId },
        select: { id: true, name: true, color: true },
      }),
      prisma.$queryRaw`
      SELECT
        to_char(m.month, 'YYYY-MM') AS month,
        COALESCE(sum(t.amount) FILTER (WHERE t.kind = 'income'), 0)::text AS income,
        COALESCE(sum(t.amount) FILTER (WHERE t.kind = 'expense'), 0)::text AS expense
      FROM generate_series(
        ${start}::date - interval '5 months',
        ${start}::date,
        interval '1 month'
      ) AS m(month)
      LEFT JOIN transactions t
        ON t.user_id = ${userId}::uuid
        AND t.occurred_on >= m.month
        AND t.occurred_on < m.month + interval '1 month'
      GROUP BY m.month
      ORDER BY m.month
    `,
    ],
  );
  const totalsByKind = new Map(totals.map((item) => [item.kind, item]));
  const income = totalsByKind.get("income");
  const expense = totalsByKind.get("expense");
  const categoryById = new Map(
    categories.map((category) => [category.id, category]),
  );
  const byCategory = categoryTotals
    .map((item) => ({
      ...categoryById.get(item.categoryId),
      amount: item._sum.amount.toString(),
    }))
    .sort((left, right) => {
      const difference = BigInt(right.amount) - BigInt(left.amount);
      return difference === 0n
        ? left.name.localeCompare(right.name)
        : difference > 0n
          ? 1
          : -1;
    });
  return {
    month,
    income: income?._sum.amount?.toString() ?? "0",
    expense: expense?._sum.amount?.toString() ?? "0",
    balance: (
      BigInt(income?._sum.amount?.toString() ?? "0") -
      BigInt(expense?._sum.amount?.toString() ?? "0")
    ).toString(),
    count: (income?._count._all ?? 0) + (expense?._count._all ?? 0),
    byCategory,
    trend,
  };
}
