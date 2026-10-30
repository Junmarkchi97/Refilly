// Supabase Auth "Send SMS" hook -> UniSMS (https://unismsapi.com/docs/sms).
// Secrets: SEND_SMS_HOOK_SECRET (v1,whsec_...), UNISMS_API_KEY, optional UNISMS_SENDER_ID (default "Unisoft" test sender).
import { Webhook } from "https://esm.sh/standardwebhooks@1.0.0";

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });

const hookError = (status: number, message: string) => json(status, { error: { http_code: status, message } });

/** Normalises PH mobiles to +639XXXXXXXXX (UniSMS also accepts 09XXXXXXXXX). */
export function toPhMobile(raw: string): string | null {
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
  const number = toPhMobile(phone);
  if (!number || !otp) return hookError(400, "Only Philippine mobile numbers (+63 9XX XXX XXXX) are supported");

  const message = `Your Refilly code is ${otp}. It expires in 10 minutes. Do not share it.`;
  try {
    const err = await sendUniSms(number, message);
    if (err) {
      console.error(`send-sms: ${err}`);
      const missing = err.startsWith("not configured");
      return hookError(missing ? 500 : 502, missing ? "SMS provider is not configured yet" : "Could not send the SMS code. Please try again.");
    }
    console.log(`send-sms: sent to ${number.slice(0, 4)}*****${number.slice(-2)}`);
    return json(200, {});
  } catch (e) {
    console.error("send-sms: network error", String(e));
    return hookError(502, "SMS provider unreachable");
  }
});

/** UniSMS: POST https://unismsapi.com/api/sms, Basic auth (secret key as username, empty password). 201 on success. */
async function sendUniSms(number: string, content: string): Promise<string | null> {
  const key = Deno.env.get("UNISMS_API_KEY");
  if (!key) return "not configured: UNISMS_API_KEY missing";
  const r = await fetch("https://unismsapi.com/api/sms", {
    method: "POST",
    headers: { Authorization: "Basic " + btoa(`${key}:`), "Content-Type": "application/json" },
    body: JSON.stringify({
      recipient: "+63" + number.slice(1),
      content,
      sender_id: Deno.env.get("UNISMS_SENDER_ID") || "Unisoft",
      metadata: { source: "refilly-otp" },
    }),
  });
  const text = await r.text();
  if (r.status !== 201 && r.status !== 200) return `UniSMS rejected (${r.status}): ${text.slice(0, 300)}`;
  try {
    const m = JSON.parse(text).message;
    if (m?.status === "failed" || m?.fail_reason) return `UniSMS failed: ${m.fail_reason ?? text.slice(0, 300)}`;
  } catch (_) { /* non-JSON 201 is still accepted */ }
  return null;
}
