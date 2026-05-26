export default function Home() {
  return (
    <main style={{ maxWidth: '800px', margin: '0 auto' }}>
      <h1 style={{ color: '#38bdf8', borderBottom: '1px solid #1e3a5f', paddingBottom: '1rem' }}>
        🔷 AWS SQS + DLQ Demo
      </h1>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ color: '#94a3b8' }}>Architecture</h2>
        <pre style={{ background: '#1e293b', padding: '1rem', borderRadius: '8px', color: '#86efac', fontSize: '0.85rem' }}>
{`  Client ──► POST /api/success ──► SQS orders-queue ──► Order Processor
                                                              │
                                                         ✅ Valid → Delete (success log)
                                                         ❌ Invalid → Retry x3 → DLQ
                                                                           │
  Client ──► POST /api/fail ─────────────────────────────────────► Failure Processor
                                                                    (failure log)`}
        </pre>
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ color: '#94a3b8' }}>API Endpoints</h2>
        <div style={{ display: 'grid', gap: '1rem' }}>
          <div style={{ background: '#1e293b', padding: '1rem', borderRadius: '8px', borderLeft: '4px solid #22c55e' }}>
            <code style={{ color: '#22c55e' }}>POST /api/success</code>
            <p style={{ margin: '0.5rem 0 0', color: '#94a3b8', fontSize: '0.9rem' }}>
              Sends a valid order to SQS → Order Processor logs success and deletes the message.
            </p>
          </div>
          <div style={{ background: '#1e293b', padding: '1rem', borderRadius: '8px', borderLeft: '4px solid #ef4444' }}>
            <code style={{ color: '#ef4444' }}>POST /api/fail</code>
            <p style={{ margin: '0.5rem 0 0', color: '#94a3b8', fontSize: '0.9rem' }}>
              Sends an invalid order to SQS → Order Processor throws error → after 3 retries message moves to DLQ → Failure Processor logs failure.
            </p>
          </div>
        </div>
      </section>

      <section>
        <h2 style={{ color: '#94a3b8' }}>Quick Start</h2>
        <pre style={{ background: '#1e293b', padding: '1rem', borderRadius: '8px', color: '#fbbf24', fontSize: '0.85rem' }}>
{`# 1. Start LocalStack
npm run docker:up

# 2. Create SQS queues
npm run setup:queues

# 3. Start Next.js app
npm run dev

# 4. Start Order Processor worker
npm run worker:order

# 5. Start Failure Processor worker
npm run worker:failure

# 6. Send test messages
curl -X POST http://localhost:3000/api/success
curl -X POST http://localhost:3000/api/fail`}
        </pre>
      </section>
    </main>
  );
}
