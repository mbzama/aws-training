"use client";

import { useState, useEffect, useRef } from "react";
import { createAppSyncSubscription, type ReceivedEvent } from "@/lib/appsync";

interface Props {
  defaultChannel?: string;
}

type ConnectionStatus = "idle" | "connecting" | "connected" | "disconnected" | "error";

const STATUS_STYLES: Record<ConnectionStatus, string> = {
  idle: "bg-gray-700 text-gray-300",
  connecting: "bg-yellow-700 text-yellow-200",
  connected: "bg-green-700 text-green-200",
  disconnected: "bg-gray-700 text-gray-300",
  error: "bg-red-700 text-red-200",
};

export default function EventSubscriber({ defaultChannel = "/default/chat" }: Props) {
  const [channel, setChannel] = useState(defaultChannel);
  const [status, setStatus] = useState<ConnectionStatus>("idle");
  const [events, setEvents] = useState<ReceivedEvent[]>([]);
  const unsubscribeRef = useRef<(() => void) | null>(null);
  const bottomRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [events]);

  function connect() {
    if (unsubscribeRef.current) return;

    const unsub = createAppSyncSubscription(
      channel,
      (event) => setEvents((prev) => [event, ...prev].slice(0, 100)),
      (s) => setStatus(s as ConnectionStatus)
    );
    unsubscribeRef.current = unsub;
  }

  function disconnect() {
    unsubscribeRef.current?.();
    unsubscribeRef.current = null;
    setStatus("idle");
  }

  const isConnected = status === "connected" || status === "connecting";

  return (
    <div className="flex h-full flex-col rounded-xl border border-gray-800 bg-gray-900 p-6">
      <div className="mb-4 flex items-center justify-between">
        <h2 className="text-lg font-semibold text-white">Subscribe</h2>
        <span className={`rounded-full px-2 py-0.5 text-xs font-medium ${STATUS_STYLES[status]}`}>
          {status}
        </span>
      </div>

      <div className="mb-4 flex gap-2">
        <input
          type="text"
          value={channel}
          onChange={(e) => setChannel(e.target.value)}
          disabled={isConnected}
          placeholder="/default/my-channel"
          className="flex-1 rounded-lg border border-gray-700 bg-gray-800 px-3 py-2 text-sm text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-blue-500 disabled:opacity-50"
        />
        {!isConnected ? (
          <button
            onClick={connect}
            className="rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white transition hover:bg-blue-500"
          >
            Connect
          </button>
        ) : (
          <button
            onClick={disconnect}
            className="rounded-lg bg-gray-700 px-4 py-2 text-sm font-medium text-white transition hover:bg-gray-600"
          >
            Disconnect
          </button>
        )}
      </div>

      <div className="flex-1 overflow-y-auto rounded-lg border border-gray-800 bg-gray-950 p-3">
        {events.length === 0 ? (
          <p className="text-center text-sm text-gray-600">
            {isConnected ? "Waiting for events..." : "Connect to start receiving events."}
          </p>
        ) : (
          <ul className="space-y-2">
            {events.map((ev) => (
              <li key={ev.id} className="rounded-lg border border-gray-800 bg-gray-900 p-3">
                <div className="mb-1 flex items-center justify-between">
                  <span className="text-xs font-medium text-blue-400">{ev.channel}</span>
                  <span className="text-xs text-gray-500">
                    {new Date(ev.timestamp).toLocaleTimeString()}
                  </span>
                </div>
                <pre className="overflow-x-auto whitespace-pre-wrap break-all text-xs text-gray-300">
                  {JSON.stringify(ev.payload, null, 2)}
                </pre>
              </li>
            ))}
          </ul>
        )}
        <div ref={bottomRef} />
      </div>

      {events.length > 0 && (
        <button
          onClick={() => setEvents([])}
          className="mt-3 text-xs text-gray-500 underline hover:text-gray-400"
        >
          Clear events
        </button>
      )}
    </div>
  );
}
