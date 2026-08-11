export interface AppConfig {
  port: number;
  aws: {
    region: string;
    accessKeyId?: string;
    secretAccessKey?: string;
    sessionToken?: string;
    profile?: string;
  };
  terminologyName: string;
}

export default (): AppConfig => ({
  port: parseInt(process.env.PORT ?? '3000', 10),
  aws: {
    region: process.env.AWS_REGION ?? 'us-east-1',
    // Explicit keys are optional. When omitted, the AWS SDK's default
    // credential provider chain resolves credentials itself — from
    // AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY exported in the shell, from
    // AWS_PROFILE / ~/.aws/credentials, or from an EC2/ECS/Lambda role.
    accessKeyId: process.env.AWS_ACCESS_KEY_ID,
    secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY,
    sessionToken: process.env.AWS_SESSION_TOKEN,
    profile: process.env.AWS_PROFILE,
  },
  terminologyName: process.env.TERMINOLOGY_NAME ?? 'exclude-list-v1',
});
