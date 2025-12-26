import { onchainTable } from "ponder";

export const example = onchainTable("orders", (t) => ({
  id: t.text().primaryKey(),
  name: t.text(),
}));
