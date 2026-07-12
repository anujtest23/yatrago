// Standalone runner: boots the real Nest app context and invokes the actual
// AccountDeletionJob so the e2e suite exercises the cron code path (not a
// reimplementation). Prints CRON_DONE on success.
import 'dotenv/config';
import { NestFactory } from '@nestjs/core';
import { AppModule } from '../src/app.module';
import { AccountDeletionJob } from '../src/modules/users/account-deletion.job';

async function main() {
  const app = await NestFactory.createApplicationContext(AppModule, {
    logger: ['error'],
  });
  const job = app.get(AccountDeletionJob);
  await job.finalizeExpiredDeletions();
  console.log('CRON_DONE');
  // Exit immediately — avoids ioredis teardown noise from the standalone
  // context racing the main dev server's Redis client on shutdown.
  process.exit(0);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
