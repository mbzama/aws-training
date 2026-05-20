import { readFileSync } from "fs";
import {
  SecretsManagerClient,
  GetSecretValueCommand,
} from "@aws-sdk/client-secrets-manager";
import type { NextRequest } from "next/server";

const MOUNTED_SECRET_PATH = "/mnt/aws-secrets/app_web.json";

const client = new SecretsManagerClient({
  region: process.env.AWS_REGION || "us-east-1",
});

export async function GET(request: NextRequest) {
  const secretName = request.nextUrl.searchParams.get("name");

  if (!secretName) {
    return Response.json({ error: "Secret name is required" }, { status: 400 });
  }

  // When running in Docker the init service pre-fetches the secret and writes
  // it to a mounted JSON file. Read from the file if it exists; otherwise fall
  // back to calling AWS Secrets Manager directly.
  try {
    const raw = readFileSync(MOUNTED_SECRET_PATH, "utf-8");
    const secrets: Record<string, unknown> = JSON.parse(raw);
    console.log("Reading secrets from mount: "+MOUNTED_SECRET_PATH);

    if (!(secretName in secrets)) {
      return Response.json(
        { error: `Key "${secretName}" not found in mounted secret file` },
        { status: 404 }
      );
    }

    return Response.json({ name: secretName, value: String(secrets[secretName]) });
  } catch {
    // File not present — fall through to AWS SDK
  }

  try {
    console.log("Getting secrets from AWS Secrets ...");
    const command = new GetSecretValueCommand({ SecretId: secretName });
    const response = await client.send(command);
    console.log(response);

    return Response.json({ name: secretName, value: response.SecretString ?? null });
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : "Unknown error";
    return Response.json({ error: message }, { status: 500 });
  }
}
