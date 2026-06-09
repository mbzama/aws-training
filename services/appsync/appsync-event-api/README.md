# AppSync Events API Demo

A Next.js application demonstrating real-time pub/sub messaging with **AWS AppSync Events API** — a serverless WebSocket-based channel service that requires no GraphQL schema.

## Architecture

```
Browser (Next.js)
  ├── Publisher  →  Next.js Server Action  →  HTTP POST  →  AppSync Events API
  └── Subscriber →  Browser WebSocket      →  WSS conn   →  AppSync Events API
```

- **Publishing** is done server-side via a Next.js Server Action so the API key is never exposed in the browser bundle.
- **Subscribing** is done client-side using a native browser WebSocket with the `aws-appsync-event-ws` subprotocol.

---

## Prerequisites

- Node.js 20+
- An AWS account
- AWS CLI configured (`aws configure`)

---

## Step 1 — Create the AppSync Events API

### Option A: AWS Console

1. Open the [AWS AppSync console](https://console.aws.amazon.com/appsync/).
2. Click **Create API** → choose **Event API**.
3. Give it a name (e.g. `appsync-event-demo`) and click **Create**.
4. From the **Settings** tab, copy:
   - **HTTP endpoint** — `https://<api-id>.appsync-api.<region>.amazonaws.com`
   - **Realtime endpoint** — `wss://<api-id>.appsync-realtime-api.<region>.amazonaws.com`
5. From the **API keys** tab, copy the API key value (`da2-…`).

### Option B: AWS CLI

```bash
# Create the Event API
aws appsync create-api \
  --name appsync-event-demo \
  --event-config '{"authProviders":[{"authType":"API_KEY"}],"connectionAuthModes":[{"authType":"API_KEY"}],"defaultPublishAuthModes":[{"authType":"API_KEY"}],"defaultSubscribeAuthModes":[{"authType":"API_KEY"}]}'

# Note the apiId from the response, then create an API key
aws appsync create-api-key --api-id <apiId>
```

### Step 1b — Create a Channel Namespace

AppSync Events API uses **namespaces** to group channels. Create a default namespace:

**Console:** API → **Namespaces** tab → **Create namespace** → name it `default`.

**CLI:**
```bash
aws appsync create-channel-namespace \
  --api-id <apiId> \
  --name default
```

Channels are then addressed as `/default/<channel-name>` (e.g. `/default/chat`).

---

## Step 2 — Configure environment variables

```bash
cp .env.local.example .env.local
```

Edit `.env.local` and fill in the values from Step 1:

```env
# Server-side (not exposed to the browser)
APPSYNC_HTTP_ENDPOINT=https://<api-id>.appsync-api.<region>.amazonaws.com/event
APPSYNC_API_KEY=da2-xxxxxxxxxxxxxxxxxxxxxxxxxxxx

# Client-side (visible in the browser — acceptable for API_KEY demo auth)
NEXT_PUBLIC_APPSYNC_REALTIME_ENDPOINT=wss://<api-id>.appsync-realtime-api.<region>.amazonaws.com/event
NEXT_PUBLIC_APPSYNC_API_KEY=da2-xxxxxxxxxxxxxxxxxxxxxxxxxxxx
NEXT_PUBLIC_APPSYNC_HTTP_HOST=<api-id>.appsync-api.<region>.amazonaws.com
NEXT_PUBLIC_AWS_REGION=us-east-1
```

> **Note:** For production workloads, replace API_KEY auth with **Amazon Cognito** or **AWS IAM** so credentials are not exposed in the browser.

---

## Step 3 — Install dependencies and run

```bash
npm install
npm run dev
```

Open [http://localhost:3000](http://localhost:3000).

---

## Using the demo

1. **Subscribe** — enter a channel path (e.g. `/default/chat`) in the right panel and click **Connect**.
2. **Publish** — enter the same channel path in the left panel, type a message, and click **Publish**.
3. The event appears in the subscriber panel in real time.

Open the app in multiple browser tabs to see multi-client delivery.

---

## Testing from the AWS Console

The AppSync console has a built-in **Events** tab that lets you publish and subscribe without running the app locally — useful for verifying the API is configured correctly before wiring up the Next.js app.

### Subscribe to a channel

1. Open your API in the [AppSync console](https://console.aws.amazon.com/appsync/).
2. Click the **Events** tab in the left sidebar.
3. Under **Subscribe**, enter a channel path: `/default/chat`
4. Click **Subscribe**. The panel shows `Subscribed to /default/chat` and waits for incoming events.

Keep this tab open — you will see events appear here when you publish in the next step.

### Publish an event

1. In a **second browser tab**, open the same API → **Events** tab.
2. Under **Publish**, set the channel to the same path: `/default/chat`
3. Enter a JSON event payload, for example:
   ```json
   { "message": "Hello from the console!", "user": "tester" }
   ```
4. Click **Publish**. The event appears immediately in the subscriber tab.

> The console uses your currently signed-in IAM identity, so no API key is needed here. This is also a good way to confirm the namespace and channel path are correct before configuring your app.

### Publish via curl (quick smoke test)

Once you have your HTTP endpoint and API key, you can publish from the terminal without running the app:

```bash
curl -X POST https://<api-id>.appsync-api.<region>.amazonaws.com/event \
  -H "Content-Type: application/json" \
  -H "x-api-key: da2-xxxxxxxxxxxxxxxxxxxxxxxxxxxx" \
  -d '{"channel":"/default/chat","events":["{\"message\":\"hello from curl\"}"]}'
```

A `200 OK` with `{"failed":[],"successful":[...]}` confirms the event was accepted and delivered to all subscribers.

---

## Project structure

```
.
├── app/
│   ├── actions.ts          # Server Action: publishes events via HTTP POST
│   ├── layout.tsx
│   ├── page.tsx            # Main demo page
│   └── globals.css
├── components/
│   ├── EventPublisher.tsx  # Publish form (calls the server action)
│   └── EventSubscriber.tsx # WebSocket subscriber (browser-side)
├── lib/
│   └── appsync.ts          # WebSocket connection helpers
├── .env.local.example
└── README.md
```

---

## Key concepts

| Concept | Detail |
|---|---|
| **Channel** | A named pub/sub topic, e.g. `/default/chat` |
| **Namespace** | Groups channels; must exist before publishing (`default` above) |
| **Publish** | HTTP `POST /event` with `{ channel, events: [jsonString] }` |
| **Subscribe** | WebSocket with subprotocol `aws-appsync-event-ws` |
| **Auth** | API_KEY (demo) · IAM · Cognito · OIDC · Lambda |

---

## Cleanup

```bash
# Delete the API (also removes all namespaces and API keys)
aws appsync delete-api --api-id <apiId>
```
