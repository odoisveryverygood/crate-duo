// POST /api/waitlist {email} -> one JSON file per signup in the project's Vercel Blob store (waitlist/…).
// List signups: `vercel blob list --prefix waitlist/` or tools in the repo README.
import { put } from "@vercel/blob";
import { createHash } from "node:crypto";

export default async function handler(req, res) {
  if (req.method !== "POST") {
    res.setHeader("Allow", "POST");
    return res.status(405).json({ ok: false });
  }
  let body = req.body;
  if (typeof body === "string") {
    try { body = JSON.parse(body); } catch { body = {}; }
  }
  // honeypot: bots fill every field
  if (body?.company) return res.status(200).json({ ok: true });

  const email = String(body?.email ?? "").trim().toLowerCase();
  if (email.length > 254 || !/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(email)) {
    return res.status(400).json({ ok: false, error: "invalid_email" });
  }
  const id = createHash("sha256").update(email).digest("hex").slice(0, 20);
  const record = {
    email,
    at: new Date().toISOString(),
    country: req.headers["x-vercel-ip-country"] || "",
    referer: req.headers.referer || "",
  };
  try {
    await put(`waitlist/${id}.json`, JSON.stringify(record), {
      access: "private",
      addRandomSuffix: true,
      contentType: "application/json",
    });
  } catch (e) {
    console.error("waitlist put failed", e);
    return res.status(500).json({ ok: false });
  }
  return res.status(200).json({ ok: true });
}
