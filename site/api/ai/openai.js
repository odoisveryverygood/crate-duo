// POST /api/ai/openai  (header x-crate-token)  -> OpenAI Responses API with the server-held key.
// Only the fields CRATE sends are forwarded; models are allow-listed and output is capped.
const MODELS = new Set(["gpt-6-luna", "gpt-6-sol"]);
const hits = new Map(); // best-effort per-instance rate limit: ip -> [timestamps]

function limited(ip, max = 40, windowMs = 60_000) {
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
  if (!b || !MODELS.has(b.model)) return res.status(400).json({ error: "model" });
  const input = String(b.input ?? "");
  const instructions = String(b.instructions ?? "");
  if (input.length > 20_000 || instructions.length > 20_000) return res.status(413).json({ error: "too_large" });

  const body = {
    model: b.model,
    reasoning: { effort: "none" },
    instructions,
    input,
    text: b.text,
    max_output_tokens: 4000,
  };
  const r = await fetch("https://api.openai.com/v1/responses", {
    method: "POST",
    headers: { Authorization: `Bearer ${process.env.OPENAI_API_KEY}`, "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  const text = await r.text();
  res.status(r.status).setHeader("Content-Type", "application/json").send(text);
}
