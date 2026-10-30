// Supabase Auth "Send SMS" hook -> Semaphore (semaphore.co) OTP API.
// Secrets: SEND_SMS_HOOK_SECRET (v1,whsec_...), SEMAPHORE_API_KEY, optional SEMAPHORE_SENDER_NAME.
import { Webhook } from "https://esm.sh/standardwebhooks@1.0.0";

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });

const hookError = (status: number, message: string) => json(status, { error: { http_code: status, message } });

/** Semaphore wants PH mobiles as 09XXXXXXXXX (63XXXXXXXXXX also accepted). */
export function toSemaphoreNumber(raw: string): string | null {
  const d = raw.replace(/\D/g, "");
  if (/^639\d{9}$/.test(d)) return "0" + d.slice(2);
  if (/^09\d{9}$/.test(d)) return d;
  if (/^9\d{9}$/.test(d)) return "0" + d;
  return null;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return hookError(405, "Method not allowed");
  const payload = await req.text();
  const secret = (Deno.env.get("SEND_SMS_HOOK_SECRET") ?? "").replace("v1,whsec_", "");
  let data: { user?: { phone?: string }; sms?: { otp?: string } };
  try {
    data = new Webhook(secret).verify(payload, Object.fromEntries(req.headers)) as typeof data;
  } catch (_) {
    return hookError(401, "Invalid hook signature");
  }

  const phone = data.user?.phone ?? "";
  const otp = data.sms?.otp ?? "";
  const number = toSemaphoreNumber(phone);
  if (!number || !otp) return hookError(400, "Only Philippine mobile numbers (+63 9XX XXX XXXX) are supported");

  const apikey = Deno.env.get("SEMAPHORE_API_KEY");
  if (!apikey) {
    console.error("send-sms: SEMAPHORE_API_KEY is not set");
    return hookError(500, "SMS provider is not configured yet");
  }

  const form = new URLSearchParams({ apikey, number, code: otp, message: "Your Refilly code is {otp}. It expires in 10 minutes. Do not share it." });
  const sender = Deno.env.get("SEMAPHORE_SENDER_NAME");
  if (sender) form.set("sendername", sender);

  try {
    const r = await fetch("https://api.semaphore.co/api/v4/otp", { method: "POST", body: form });
    const text = await r.text();
    let ok = r.ok;
    try {
      const j = JSON.parse(text);
      if (!Array.isArray(j) || j.length === 0 || j.some((m) => m.status === "Failed")) ok = false;
    } catch (_) {
      ok = false;
    }
    if (!ok) {
      console.error(`send-sms: Semaphore rejected (${r.status}): ${text.slice(0, 300)}`);
      return hookError(502, "Could not send the SMS code. Please try again.");
    }
    console.log(`send-sms: sent to ${number.slice(0, 4)}*****${number.slice(-2)}`);
    return json(200, {});
  } catch (e) {
    console.error("send-sms: network error", String(e));
    return hookError(502, "SMS provider unreachable");
  }
});
