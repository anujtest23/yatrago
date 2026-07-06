/**
 * Managed-secret hydration. Runs BEFORE any application module is imported
 * (see main.ts — the AppModule import is deferred until this resolves), so
 * app.config.ts sees a fully-populated process.env.
 *
 * Providers (SECRETS_PROVIDER):
 *   aws   — AWS Secrets Manager   (SECRETS_NAME, AWS_REGION + IAM creds)
 *   gcp   — GCP Secret Manager    (SECRETS_NAME = projects/x/secrets/y/versions/latest)
 *   azure — Azure Key Vault       (AZURE_KEY_VAULT_URL, SECRETS_NAME)
 *   unset — no-op (plain env vars / dotenv; fine for dev, discouraged in prod)
 *
 * The secret value must be a JSON object: { "JWT_ACCESS_SECRET": "...", ... }.
 * Values are merged into process.env WITHOUT overwriting explicitly-set vars,
 * so an operator can still override a single key at deploy time.
 *
 * SDKs are loaded dynamically so they stay optional dependencies — install
 * only the one you use:
 *   aws   → @aws-sdk/client-secrets-manager
 *   gcp   → @google-cloud/secret-manager
 *   azure → @azure/keyvault-secrets + @azure/identity
 *
 * Fail-secure: in production a configured provider that cannot be reached
 * aborts boot rather than starting with missing secrets.
 */

/* eslint-disable @typescript-eslint/no-unsafe-assignment,
   @typescript-eslint/no-unsafe-member-access,
   @typescript-eslint/no-unsafe-call */

// SDK module names go through a variable so neither tsc nor eslint tries to
// resolve them at build time — they are OPTIONAL dependencies, installed
// only in deployments that use the matching provider.
function importOptional(specifier: string): Promise<any> {
  return import(specifier);
}

function mergeIntoEnv(json: string, source: string): void {
  let parsed: unknown;
  try {
    parsed = JSON.parse(json);
  } catch {
    throw new Error(`Secret payload from ${source} is not valid JSON.`);
  }
  if (typeof parsed !== 'object' || parsed === null || Array.isArray(parsed)) {
    throw new Error(`Secret payload from ${source} must be a JSON object.`);
  }
  let applied = 0;
  for (const [key, value] of Object.entries(parsed)) {
    if (process.env[key] !== undefined) continue; // explicit env wins
    if (typeof value !== 'string') continue;
    process.env[key] = value;
    applied++;
  }
  console.log(`[secrets] loaded ${applied} secret(s) from ${source}`);
}

async function loadAws(secretName: string): Promise<void> {
  const mod = await importOptional('@aws-sdk/client-secrets-manager');
  const client = new mod.SecretsManagerClient({});
  const res = await client.send(
    new mod.GetSecretValueCommand({ SecretId: secretName }),
  );
  const payload: string | undefined =
    res.SecretString ??
    (res.SecretBinary
      ? Buffer.from(res.SecretBinary).toString('utf8')
      : undefined);
  if (!payload) throw new Error(`AWS secret ${secretName} has no value.`);
  mergeIntoEnv(payload, 'AWS Secrets Manager');
}

async function loadGcp(secretName: string): Promise<void> {
  const mod = await importOptional('@google-cloud/secret-manager');
  const client = new mod.SecretManagerServiceClient();
  const [version] = await client.accessSecretVersion({ name: secretName });
  const payload = version?.payload?.data?.toString();
  if (!payload) throw new Error(`GCP secret ${secretName} has no value.`);
  mergeIntoEnv(payload, 'GCP Secret Manager');
}

async function loadAzure(secretName: string): Promise<void> {
  const vaultUrl = process.env.AZURE_KEY_VAULT_URL;
  if (!vaultUrl) {
    throw new Error(
      'AZURE_KEY_VAULT_URL must be set for SECRETS_PROVIDER=azure.',
    );
  }
  const secrets = await importOptional('@azure/keyvault-secrets');
  const identity = await importOptional('@azure/identity');
  const client = new secrets.SecretClient(
    vaultUrl,
    new identity.DefaultAzureCredential(),
  );
  const secret = await client.getSecret(secretName);
  if (!secret.value)
    throw new Error(`Azure secret ${secretName} has no value.`);
  mergeIntoEnv(secret.value, 'Azure Key Vault');
}

export async function loadManagedSecrets(): Promise<void> {
  const provider = (process.env.SECRETS_PROVIDER ?? '').toLowerCase().trim();
  if (!provider || provider === 'none') return;

  const secretName = process.env.SECRETS_NAME;
  if (!secretName) {
    throw new Error('SECRETS_NAME must be set when SECRETS_PROVIDER is used.');
  }

  try {
    switch (provider) {
      case 'aws':
        await loadAws(secretName);
        break;
      case 'gcp':
        await loadGcp(secretName);
        break;
      case 'azure':
        await loadAzure(secretName);
        break;
      default:
        throw new Error(
          `Unknown SECRETS_PROVIDER '${provider}' (expected aws | gcp | azure).`,
        );
    }
  } catch (error) {
    // Fail secure: a configured-but-broken secret source must never result
    // in the app booting on defaults or partial config.
    throw new Error(
      `FATAL: failed to load secrets via '${provider}': ${(error as Error).message}`,
    );
  }
}
