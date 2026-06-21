import path from 'node:path';
import { defineConfig } from 'prisma/config';

export default defineConfig({
  schema: path.join('prisma', 'schema.prisma'),

  async adapter() {
    const { PrismaPg } = await import('@prisma/adapter-pg');

    return new PrismaPg({
      connectionString: process.env.DATABASE_URL!,
    });
  },
});