"use server";

export interface PublishResult {
  ok: boolean;
  error?: string;
}

export async function publishEvent(channel: string, payload: unknown): Promise<PublishResult> {
  const endpoint = process.env.APPSYNC_HTTP_ENDPOINT;
  const apiKey = process.env.APPSYNC_API_KEY;

  if (!endpoint || !apiKey) {
    return { ok: false, error: "AppSync endpoint or API key is not configured." };
  }

  const res = await fetch(endpoint, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-api-key": apiKey,
    },
    body: JSON.stringify({
      channel,
      events: [JSON.stringify(payload)],
    }),
  });

  if (!res.ok) {
    const text = await res.text();
    return { ok: false, error: `HTTP ${res.status}: ${text}` };
  }

  return { ok: true };
}
