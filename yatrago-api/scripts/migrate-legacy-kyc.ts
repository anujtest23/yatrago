/**
 * One-off migration: move legacy KYC documents that were stored in the
 * PUBLIC uploads folder (fileUrl starting with `/uploads/`) into the private
 * store and rewrite their DB rows to the private `kyc/<name>` key form so
 * they are served only via signed URLs.
 *
 * Safe to re-run: rows already in `kyc/` form are skipped. Files missing on
 * disk are reported and left for manual handling.
 *
 *   npx ts-node scripts/migrate-legacy-kyc.ts          # dry run
 *   npx ts-node scripts/migrate-legacy-kyc.ts --apply  # perform changes
 */
import { PrismaClient } from '@prisma/client';
import { existsSync, mkdirSync, renameSync } from 'fs';
import { basename, join, resolve } from 'path';

const prisma = new PrismaClient();
const APPLY = process.argv.includes('--apply');

const PUBLIC_DIR = resolve('./uploads');
const PRIVATE_DIR = resolve('./uploads-private/kyc');

async function migrateModel(
  name: string,
  rows: { id: string; fileUrl: string }[],
  update: (id: string, key: string) => Promise<unknown>,
) {
  let moved = 0;
  let missing = 0;
  for (const row of rows) {
    if (!row.fileUrl.startsWith('/uploads/')) continue;
    const filename = basename(row.fileUrl);
    const src = join(PUBLIC_DIR, filename);
    const key = `kyc/${filename}`;

    if (!existsSync(src)) {
      missing++;
      console.warn(`  [${name}] missing file on disk: ${row.fileUrl}`);
      if (APPLY) await update(row.id, key); // still repoint the row
      continue;
    }
    if (APPLY) {
      mkdirSync(PRIVATE_DIR, { recursive: true });
      renameSync(src, join(PRIVATE_DIR, filename));
      await update(row.id, key);
    }
    moved++;
  }
  console.log(
    `${name}: ${moved} to migrate, ${missing} missing${APPLY ? ' (applied)' : ' (dry run)'}`,
  );
}

async function main() {
  const driverDocs = await prisma.driverDocument.findMany({
    select: { id: true, fileUrl: true },
  });
  await migrateModel('DriverDocument', driverDocs, (id, fileUrl) =>
    prisma.driverDocument.update({ where: { id }, data: { fileUrl } }),
  );

  const vehicleDocs = await prisma.vehicleDocument.findMany({
    select: { id: true, fileUrl: true },
  });
  await migrateModel('VehicleDocument', vehicleDocs, (id, fileUrl) =>
    prisma.vehicleDocument.update({ where: { id }, data: { fileUrl } }),
  );

  if (!APPLY) {
    console.log('\nDry run complete. Re-run with --apply to perform changes.');
  }
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
