import { createPrismaClient } from "../src/prisma.js";
import { hashPassword } from "../src/modules/auth/auth.service.js";
import { insertDefaultCategories } from "../src/modules/categories/category.repository.js";
const prisma = createPrismaClient();
const parts = new Intl.DateTimeFormat("en-CA", {
  timeZone: "Asia/Ho_Chi_Minh",
  year: "numeric",
  month: "2-digit",
}).formatToParts(new Date());
const month = `${parts.find((part) => part.type === "year").value}-${parts.find((part) => part.type === "month").value}`;
try {
  const seeded = await prisma.$transaction(async (tx) => {
    const existing = await tx.user.findUnique({
      where: { email: "demo@example.com" },
      select: { id: true },
    });
    if (existing) return false;
    const user = await tx.user.create({
      data: {
        name: "Người dùng mẫu",
        email: "demo@example.com",
        passwordHash: await hashPassword("Demo@12345"),
      },
      select: { id: true },
    });
    await insertDefaultCategories(tx, user.id);
    const categories = await tx.category.findMany({
      where: { userId: user.id },
      select: { id: true, name: true, kind: true },
    });
    const category = (name) => categories.find((item) => item.name === name);
    for (const [name, amount, day, note] of [
      ["Lương", 12000000, "01", "Lương tháng"],
      ["Ăn uống", 65000, "02", "Ăn trưa"],
      ["Di chuyển", 150000, "02", "Đổ xăng"],
      ["Nhà ở", 2500000, "03", "Tiền thuê phòng"],
      ["Mua sắm", 450000, "03", "Đồ dùng cá nhân"],
      ["Ăn uống", 120000, "04", "Đi chợ"],
    ]) {
      const cat = category(name);
      await tx.transaction.create({
        data: {
          userId: user.id,
          categoryId: cat.id,
          kind: cat.kind,
          amount,
          occurredOn: new Date(`${month}-${day}T00:00:00.000Z`),
          note,
        },
      });
    }
    await tx.budget.createMany({
      data: [
        ["Ăn uống", 2000000],
        ["Di chuyển", 600000],
        ["Mua sắm", 400000],
      ].map(([name, amount]) => ({
        userId: user.id,
        categoryId: category(name).id,
        month: new Date(`${month}-01T00:00:00.000Z`),
        amount,
      })),
    });
    return true;
  });
  if (seeded)
    console.log(`Created demo@example.com / Demo@12345 with data for ${month}`);
  else console.log("Demo account already exists. No data changed.");
} finally {
  await prisma.$disconnect();
}
