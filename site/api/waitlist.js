// POST /api/waitlist
//   {email, source?}      -> waitlist/<hash>-<rand>.json  (one per signup)
//   {email, role}         -> roles/<hash>.json            (the one-tap "you…" answer; latest wins)
// Private Vercel Blob store. Export: node waitlist-export.mjs [--csv]
import { put } from "@vercel/blob";
import { createHash } from "node:crypto";

const ROLES = new Set(["beats", "sing", "dj", "instrument", "curious"]);

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

  try {
    if (body?.role !== undefined) {
      const role = String(body.role);
      if (!ROLES.has(role)) return res.status(400).json({ ok: false, error: "invalid_role" });
      await put(`roles/${id}.json`, JSON.stringify({ email, role, at: new Date().toISOString() }), {
        access: "private", addRandomSuffix: false, allowOverwrite: true, contentType: "application/json",
      });
      return res.status(200).json({ ok: true });
    }
    const source = String(body?.source ?? "").toLowerCase().replace(/[^a-z0-9_.-]/g, "").slice(0, 24);
    const record = {
      email,
      at: new Date().toISOString(),
      source,
      country: req.headers["x-vercel-ip-country"] || "",
      referer: req.headers.referer || "",
    };
    await put(`waitlist/${id}.json`, JSON.stringify(record), {
      access: "private", addRandomSuffix: true, contentType: "application/json",
    });
  } catch (e) {
    console.error("waitlist put failed", e);
    return res.status(500).json({ ok: false });
  }
  return res.status(200).json({ ok: true });
}
