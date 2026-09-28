// Export the CRATE waitlist:  cd site && vercel env pull .env.local && node waitlist-export.mjs [--csv] [--delete email]
import { list, get, del } from "@vercel/blob";
import { readFileSync } from "node:fs";
for (const line of readFileSync(new URL(".env.local", import.meta.url), "utf8").split("\n")) {
  const m = line.match(/^BLOB_READ_WRITE_TOKEN="?([^"]*)"?$/); if (m) process.env.BLOB_READ_WRITE_TOKEN = m[1];
}
const args = process.argv.slice(2);
const rows = [];
let cursor;
do {
  const page = await list({ prefix: "waitlist/", cursor });
  for (const b of page.blobs) {
    const r = await get(b.pathname, { access: "private" });
    const text = await new Response(r.stream).text();
    rows.push({ ...JSON.parse(text), pathname: b.pathname });
  }
  cursor = page.cursor;
} while (cursor);
const di = args.indexOf("--delete");
if (di >= 0) {
  const target = (args[di + 1] || "").toLowerCase();
  const hit = rows.filter(r => r.email === target);
  for (const r of hit) await del(r.pathname);
  console.log(`deleted ${hit.length} entr${hit.length === 1 ? "y" : "ies"} for ${target}`);
  process.exit(0);
}
const unique = [...new Map(rows.sort((a, b) => a.at.localeCompare(b.at)).map(r => [r.email, r])).values()];
if (args.includes("--csv")) {
  console.log("email,signed_up,country");
  for (const r of unique) console.log(`${r.email},${r.at},${r.country}`);
} else {
  for (const r of unique) console.log(r.at.slice(0, 16).replace("T", " "), r.email, r.country);
  console.log(`\n${unique.length} signup${unique.length === 1 ? "" : "s"}`);
}
