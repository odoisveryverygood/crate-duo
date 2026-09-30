// POST /api/ai/jev  (header x-crate-token)  -> TypeSafe Jev System-1 (api.typesafe.ai) with the server-held key.
const hits = new Map();

function limited(ip, max = 120, windowMs = 60_000) {
  const now = Date.now();
  const list = (hits.get(ip) || []).filter(t => now - t < windowMs);
  list.push(now);
  hits.set(ip, list);
  return list.length > max;
}

export default async function handler(req, res) {
  if (req.method !== "POST") return res.status(405).json({ error: "method" });
  if (!process.env.CRATE_APP_TOKEN || req.headers["x-crate-token"] !== process.env.CRATE_APP_TOKEN) {
    return res.status(401).json({ error: "unauthorized" });
  }
  const ip = String(req.headers["x-forwarded-for"] || "").split(",")[0].trim() || "?";
  if (limited(ip)) return res.status(429).json({ error: "rate_limited" });

  let b = req.body;
  if (typeof b === "string") { try { b = JSON.parse(b); } catch { b = {}; } }
  const state = String(b?.state ?? "");
  if (!state || state.length > 8_000 || typeof b?.questions !== "object") return res.status(400).json({ error: "bad_request" });

  const r = await fetch("https://api.typesafe.ai/v1/systemone", {
    method: "POST",
    headers: { Authorization: `Bearer ${process.env.TYPESAFE_API_KEY}`, "Content-Type": "application/json" },
    body: JSON.stringify({ model: "jev-latest", state, questions: b.questions }),
  });
  const text = await r.text();
  res.status(r.status).setHeader("Content-Type", "application/json").send(text);
}
