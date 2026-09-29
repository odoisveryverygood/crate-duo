// Export the CRATE waitlist:  cd site && node waitlist-export.mjs [--csv] [--delete email]
// Shows each signup with its source (?r=… / referrer) and one-tap role, plus totals by source and role.
import { list, get, del } from "@vercel/blob";
import { readFileSync } from "node:fs";
for (const line of readFileSync(new URL(".env.local", import.meta.url), "utf8").split("\n")) {
  const m = line.match(/^BLOB_READ_WRITE_TOKEN="?([^"]*)"?$/); if (m) process.env.BLOB_READ_WRITE_TOKEN = m[1];
}
const args = process.argv.slice(2);

async function readAll(prefix) {
  const out = [];
  let cursor;
  do {
    const page = await list({ prefix, cursor });
    for (const b of page.blobs) {
      const r = await get(b.pathname, { access: "private" });
      out.push({ ...JSON.parse(await new Response(r.stream).text()), pathname: b.pathname });
    }
    cursor = page.cursor;
  } while (cursor);
  return out;
}

const rows = await readAll("waitlist/");
const roles = new Map((await readAll("roles/")).map(r => [r.email, r.role]));

const di = args.indexOf("--delete");
if (di >= 0) {
  const target = (args[di + 1] || "").toLowerCase();
  const hit = rows.filter(r => r.email === target);
  for (const r of hit) await del(r.pathname);
  for (const r of await readAll("roles/")) if (r.email === target) await del(r.pathname);
  console.log(`deleted ${hit.length} entr${hit.length === 1 ? "y" : "ies"} for ${target}`);
  process.exit(0);
}

const source = r => {
  if (r.source) return r.source;
  const h = r.referer ? new URL(r.referer).hostname.replace(/^www\./, "") : "";
  if (!h || h.endsWith("vercel.app")) return "";          // the waitlist page itself: unknown
  return /(^|\.)(x|twitter|t)\.co(m)?$/.test(h) ? "x" : h;
};
const unique = [...new Map(rows.sort((a, b) => a.at.localeCompare(b.at)).map(r => [r.email, r])).values()];
if (args.includes("--csv")) {
  console.log("email,signed_up,country,source,role");
  for (const r of unique) console.log(`${r.email},${r.at},${r.country},${source(r)},${roles.get(r.email) || ""}`);
} else {
  for (const r of unique) {
    console.log(r.at.slice(0, 16).replace("T", " "), r.email.padEnd(34), (r.country || "").padEnd(3),
                (source(r) || "-").padEnd(10), roles.get(r.email) || "");
  }
  const tally = f => Object.entries(unique.reduce((m, r) => { const k = f(r) || "(unknown)"; m[k] = (m[k] || 0) + 1; return m; }, {}))
    .sort((a, b) => b[1] - a[1]).map(([k, v]) => `${k} ${v}`).join(" · ");
  console.log(`\n${unique.length} signup${unique.length === 1 ? "" : "s"}`);
  console.log(`by source: ${tally(source)}`);
  console.log(`by role:   ${tally(r => roles.get(r.email))}`);
}
