# AWS Translate Service (NestJS)

A NestJS API that wraps [AWS Translate](https://docs.aws.amazon.com/translate/) to translate text and manage a custom terminology named `exclude-list-v1`.

## Setup

```bash
npm install
cp .env.example .env   # fill in AWS credentials, or leave blank (see below)
npm run start:dev
```

Swagger UI is served at `http://localhost:3000/api` once the app is running.

## Scripts

Run these with Git Bash / WSL / Linux / macOS.

- `./run.sh` — build and start the server in the foreground (Ctrl+C to stop). Prints the app and Swagger URLs on startup.
- `./run-test.sh [terminology-file]` — build, start the server, smoke test the `/`, `/api`, `/terminology`, and `/translate` endpoints, then shut it back down. Pass a terminology file to also exercise the upload endpoint (skipped otherwise).
- `./upload.sh [terminology-file]` — upload a custom terminology file to an already-running server. Defaults to `test/fixtures/exclude-list-v1.csv` when no path is given.
- `./test.sh "text to translate"` — translate English text into German, French, and Spanish against an already-running server, applying the `exclude-list-v1` terminology.

```bash
./run-test.sh test/fixtures/exclude-list-v1.csv
./test.sh "AWS and Playwright make testing stable and flaky test free."
```

## Environment variables

| Variable                | Description                                                  |
| ------------------------ | ------------------------------------------------------------- |
| `AWS_ACCESS_KEY_ID`      | AWS access key id ("client id") used to call Translate. Optional. |
| `AWS_SECRET_ACCESS_KEY`  | AWS secret access key ("client secret"). Optional.              |
| `AWS_SESSION_TOKEN`      | Session token for temporary credentials. Optional.              |
| `AWS_PROFILE`            | Named profile from `~/.aws/credentials` / `~/.aws/config`. Optional. |
| `AWS_REGION`             | AWS region, e.g. `us-east-1`                                    |
| `TERMINOLOGY_NAME`       | Name of the custom terminology resource (`exclude-list-v1`)    |
| `PORT`                   | HTTP port for the API (default `3000`)                         |

Credentials are resolved in this order:

1. `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` (/ `AWS_SESSION_TOKEN`) — set in `.env`, or exported directly in the terminal before `npm run start:dev` (env vars in the shell take precedence over `.env` for values `.env` leaves blank).
2. `AWS_PROFILE` — reads credentials from your local `~/.aws/credentials` (set up via `aws configure` or `aws sso login`).
3. Otherwise, the AWS SDK's default provider chain (e.g. an EC2/ECS/Lambda instance role).

The resolved IAM identity needs `translate:ImportTerminology`, `translate:GetTerminology`, and `translate:TranslateText` permissions.

## API

### `POST /terminology`

Upload (create or overwrite) the `exclude-list-v1` custom terminology from a CSV/TMX/TSV file.

```bash
curl -X POST http://localhost:3000/terminology \
  -F "file=@exclude-list-v1.csv" \
  -F "description=Terms to leave untranslated"
```

### `GET /terminology`

Read metadata and a temporary download link for the current `exclude-list-v1` terminology.

```bash
curl http://localhost:3000/terminology
```

### `POST /translate`

Translate text from a source to a target language, applying the `exclude-list-v1` terminology by default.

```bash
curl -X POST http://localhost:3000/translate \
  -H "Content-Type: application/json" \
  -d '{
    "text": "Hello, world!",
    "sourceLanguageCode": "en",
    "targetLanguageCode": "fr"
  }'
```

Set `"useCustomTerminology": false` in the body to translate without the terminology.

## Testing with curl

See [Scripts](#scripts) above for `upload.sh` and `test.sh`, which wrap the upload and translate calls below. To run them manually instead, with the server running (`npm run start:dev` or `./run.sh`), run these in order against `http://localhost:3000` to exercise the full flow using the sample fixture at `test/fixtures/exclude-list-v1.csv`:

```bash
# 1. Health check
curl http://localhost:3000/

# 2. Upload the exclude-list-v1 custom terminology
curl -X POST http://localhost:3000/terminology \
  -F "file=@test/fixtures/exclude-list-v1.csv" \
  -F "description=Terms to leave untranslated"

# 3. Read it back
curl http://localhost:3000/terminology

# 4. Translate WITHOUT the terminology — "AWS" gets translated
curl -X POST http://localhost:3000/translate \
  -H "Content-Type: application/json" \
  -d '{
    "text": "AWS and NestJS make a great pair.",
    "sourceLanguageCode": "en",
    "targetLanguageCode": "fr",
    "useCustomTerminology": false
  }'

# 5. Translate WITH the terminology — "AWS" and "NestJS" are left as-is
curl -X POST http://localhost:3000/translate \
  -H "Content-Type: application/json" \
  -d '{
    "text": "AWS and NestJS make a great pair.",
    "sourceLanguageCode": "en",
    "targetLanguageCode": "fr"
  }'
```

Note: steps 2–5 call real AWS Translate APIs and will create/update the `exclude-list-v1` terminology in whichever AWS account your credentials point to.
