import path from 'node:path';
import { defineConfig } from 'prisma/config';
import * as dotenv from 'dotenv';

dotenv.config();

const connectionString =
  process.env.DATABASE_URL ??
  'postgresql://yatrago:yatrago123@localhost:5432/yatrago_dev';

export default defineConfig({
  schema: path.join('prisma', 'schema.prisma'),
  datasource: {
    url: connectionString,
  },
});