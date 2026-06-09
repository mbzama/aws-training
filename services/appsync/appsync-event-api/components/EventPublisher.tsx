"use client";

import { useState, useTransition } from "react";
import { publishEvent } from "@/app/actions";

interface Props {
  defaultChannel?: string;
}

export default function EventPublisher({ defaultChannel = "/default/chat" }: Props) {
  const [channel, setChannel] = useState(defaultChannel);
  const [message, setMessage] = useState("");
  const [feedback, setFeedback] = useState<{ ok: boolean; text: string } | null>(null);
  const [isPending, startTransition] = useTransition();

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!message.trim()) return;

    const payload = { message: message.trim(), sentAt: new Date().toISOString() };

    startTransition(async () => {
      const result = await publishEvent(channel, payload);
      setFeedback(
        result.ok
          ? { ok: true, text: "Event published successfully." }
          : { ok: false, text: result.error ?? "Unknown error" }
      );
      if (result.ok) setMessage("");
      setTimeout(() => setFeedback(null), 3000);
    });
  }

  return (
    <div className="rounded-xl border border-gray-800 bg-gray-900 p-6">
      <h2 className="mb-4 text-lg font-semibold text-white">Publish Event</h2>

      <form onSubmit={handleSubmit} className="space-y-4">
        <div>
          <label className="mb-1 block text-sm text-gray-400">Channel</label>
          <input
            type="text"
            value={channel}
            onChange={(e) => setChannel(e.target.value)}
            placeholder="/default/my-channel"
            className="w-full rounded-lg border border-gray-700 bg-gray-800 px-3 py-2 text-sm text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-orange-500"
          />
        </div>

        <div>
          <label className="mb-1 block text-sm text-gray-400">Message</label>
          <textarea
            value={message}
            onChange={(e) => setMessage(e.target.value)}
            rows={3}
            placeholder='Hello from AppSync!'
            className="w-full rounded-lg border border-gray-700 bg-gray-800 px-3 py-2 text-sm text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-orange-500"
          />
        </div>

        <button
          type="submit"
          disabled={isPending || !message.trim()}
          className="w-full rounded-lg bg-orange-600 px-4 py-2 text-sm font-medium text-white transition hover:bg-orange-500 disabled:cursor-not-allowed disabled:opacity-50"
        >
          {isPending ? "Publishing..." : "Publish"}
        </button>

        {feedback && (
          <p className={`text-sm ${feedback.ok ? "text-green-400" : "text-red-400"}`}>
            {feedback.text}
          </p>
        )}
      </form>
    </div>
  );
}
