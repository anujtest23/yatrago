// MUST be the very first import: every other module (config, auth, guards)
// reads process.env at import time. A later dotenv.config() call would run
// AFTER those modules were evaluated and silently hand them empty values.
import 'dotenv/config';
import { loadManagedSecrets } from './config/secrets-loader';

async function start(): Promise<void> {
  // Managed secrets (AWS/GCP/Azure) must land in process.env before ANY
  // application module is evaluated — app.config.ts reads env at import
  // time, so the whole app graph is deferred behind this dynamic import.
  await loadManagedSecrets();
  const bootstrap = await import('./bootstrap.js');
  await bootstrap.run();
}

void start();
