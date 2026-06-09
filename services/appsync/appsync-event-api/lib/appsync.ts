export interface AppSyncMessage {
  type: string;
  id?: string;
  channel?: string;
  event?: string;
  errors?: { errorType: string; message: string }[];
  connectionTimeoutMs?: number;
}

export interface ReceivedEvent {
  id: string;
  channel: string;
  payload: unknown;
  timestamp: string;
}

function buildConnectionUrl(realtimeEndpoint: string, httpHost: string, apiKey: string): string {
  const headers = { host: httpHost, "x-api-key": apiKey };
  const headerB64 = btoa(JSON.stringify(headers));
  const payloadB64 = btoa("{}");
  return `${realtimeEndpoint}?header=${headerB64}&payload=${payloadB64}`;
}

export function createAppSyncSubscription(
  channel: string,
  onEvent: (event: ReceivedEvent) => void,
  onStatusChange: (status: "connecting" | "connected" | "disconnected" | "error") => void
): () => void {
  const realtimeEndpoint = process.env.NEXT_PUBLIC_APPSYNC_REALTIME_ENDPOINT!;
  const httpHost = process.env.NEXT_PUBLIC_APPSYNC_HTTP_HOST!;
  const apiKey = process.env.NEXT_PUBLIC_APPSYNC_API_KEY!;

  const subscriptionId = crypto.randomUUID();
  const url = buildConnectionUrl(realtimeEndpoint, httpHost, apiKey);

  onStatusChange("connecting");
  const ws = new WebSocket(url, "aws-appsync-event-ws");

  ws.onopen = () => {
    ws.send(JSON.stringify({ type: "connection_init" }));
  };

  ws.onmessage = (event) => {
    const msg: AppSyncMessage = JSON.parse(event.data as string);

    if (msg.type === "connection_ack") {
      onStatusChange("connected");
      ws.send(
        JSON.stringify({
          id: subscriptionId,
          type: "subscribe",
          channel,
          authorization: { host: httpHost, "x-api-key": apiKey },
        })
      );
    }

    if (msg.type === "data" && msg.id === subscriptionId && msg.event) {
      onEvent({
        id: crypto.randomUUID(),
        channel,
        payload: JSON.parse(msg.event),
        timestamp: new Date().toISOString(),
      });
    }
  };

  ws.onerror = () => onStatusChange("error");
  ws.onclose = () => onStatusChange("disconnected");

  return () => {
    if (ws.readyState === WebSocket.OPEN) {
      ws.send(JSON.stringify({ id: subscriptionId, type: "unsubscribe" }));
    }
    ws.close();
  };
}
