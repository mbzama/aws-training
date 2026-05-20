"use client";

import { useState } from "react";

export default function Home() {
  const [secretName, setSecretName] = useState("");
  const [result, setResult] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function fetchSecret() {
    if (!secretName.trim()) return;

    setLoading(true);
    setResult(null);
    setError(null);

    try {
      const res = await fetch(`/api/secret?name=${encodeURIComponent(secretName)}`);
      const data = await res.json();

      if (!res.ok) {
        setError(data.error || "Failed to fetch secret");
      } else {
        setResult(data.value);
      }
    } catch {
      setError("Network error — could not reach the server");
    } finally {
      setLoading(false);
    }
  }

  function handleKeyDown(e: React.KeyboardEvent<HTMLInputElement>) {
    if (e.key === "Enter") fetchSecret();
  }

  let parsedJson: Record<string, unknown> | null = null;
  if (result) {
    try {
      parsedJson = JSON.parse(result);
    } catch {
      // not JSON — display as plain text
    }
  }

  return (
    <main className="min-h-screen bg-gray-50 flex items-center justify-center p-6">
      <div className="w-full max-w-xl bg-white rounded-2xl shadow-md p-8">
        <h1 className="text-2xl font-bold text-gray-800 mb-1">
          AWS Secrets Manager
        </h1>
        <p className="text-sm text-gray-500 mb-6">
          Enter a secret name to retrieve its value.
        </p>

        <div className="flex gap-2">
          <input
            type="text"
            value={secretName}
            onChange={(e) => setSecretName(e.target.value)}
            onKeyDown={handleKeyDown}
            placeholder="my-app/database/password"
            className="flex-1 border border-gray-300 rounded-lg px-4 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
          <button
            onClick={fetchSecret}
            disabled={loading || !secretName.trim()}
            className="bg-blue-600 hover:bg-blue-700 disabled:bg-blue-300 text-white text-sm font-medium px-5 py-2 rounded-lg transition-colors"
          >
            {loading ? "Loading…" : "Get Secret"}
          </button>
        </div>

        {error && (
          <div className="mt-4 p-4 bg-red-50 border border-red-200 rounded-lg text-sm text-red-700">
            <span className="font-semibold">Error: </span>{error}
          </div>
        )}

        {result !== null && !error && (
          <div className="mt-4">
            <p className="text-xs font-semibold text-gray-500 uppercase tracking-wide mb-2">
              Secret Value
            </p>
            {parsedJson ? (
              <table className="w-full text-sm border border-gray-200 rounded-lg overflow-hidden">
                <thead className="bg-gray-100">
                  <tr>
                    <th className="text-left px-4 py-2 font-semibold text-gray-600 w-1/3">Key</th>
                    <th className="text-left px-4 py-2 font-semibold text-gray-600">Value</th>
                  </tr>
                </thead>
                <tbody>
                  {Object.entries(parsedJson).map(([key, val]) => (
                    <tr key={key} className="border-t border-gray-200">
                      <td className="px-4 py-2 font-mono text-gray-700">{key}</td>
                      <td className="px-4 py-2 font-mono text-gray-800 break-all">
                        {String(val)}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            ) : (
              <pre className="bg-gray-50 border border-gray-200 rounded-lg p-4 text-sm font-mono text-gray-800 break-all whitespace-pre-wrap">
                {result}
              </pre>
            )}
          </div>
        )}
      </div>
    </main>
  );
}
