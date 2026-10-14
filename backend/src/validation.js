import { z } from "zod";
export class ApiError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}
export const uuid = z.uuid();
export const kind = z.enum(["income", "expense"]);
export const money = z.number().int().min(1).max(1_000_000_000_000);
export const month = z.string().regex(/^20\d{2}-(0[1-9]|1[0-2])$/);
export const date = z
  .string()
  .regex(/^20\d{2}-\d{2}-\d{2}$/)
  .refine((s) => {
    const d = new Date(`${s}T00:00:00Z`);
    return !Number.isNaN(d.valueOf()) && d.toISOString().slice(0, 10) === s;
  }, "Ngày không hợp lệ");
export const categoryBody = z
  .object({
    name: z.string().trim().min(1).max(60),
    kind,
    color: z
      .string()
      .regex(/^#[0-9A-Fa-f]{6}$/)
      .default("#0F766E"),
  })
  .strict();
export const transactionBody = z
  .object({
    categoryId: uuid,
    kind,
    amount: money,
    occurredOn: date,
    note: z.string().trim().max(500).default(""),
    paymentMethod: z.enum(["cash", "bank", "other"]).default("cash"),
  })
  .strict();
export const budgetBody = z
  .object({ categoryId: uuid, month, amount: money })
  .strict();
export const filters = z.object({
  month: month.optional(),
  kind: kind.optional(),
  search: z.string().trim().max(100).default(""),
  page: z.coerce.number().int().min(1).max(100000).default(1),
  limit: z.coerce.number().int().min(1).max(100).default(30),
});
export function requireRow(result) {
  if (!result.rows.length) throw new ApiError(404, "Không tìm thấy dữ liệu.");
  return result.rows[0];
}
