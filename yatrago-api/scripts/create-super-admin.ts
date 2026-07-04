/**
 * Promote a user to super_admin (creating the account if it doesn't exist yet).
 *
 * Usage:
 *   npm run admin:create -- +9779812345678 "Full Name"
 *   SUPER_ADMIN_PHONE=+9779812345678 npm run admin:create
 *
 * The phone must be a valid Nepal number (+977 followed by 10 digits) so it can
 * later log in via the normal OTP flow.
 */
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  const phone = process.argv[2] ?? process.env.SUPER_ADMIN_PHONE;
  const name = process.argv[3] ?? process.env.SUPER_ADMIN_NAME ?? 'Super Admin';

  if (!phone) {
    console.error(
      'Missing phone number.\n' +
        'Usage: npm run admin:create -- +9779812345678 "Full Name"',
    );
    process.exit(1);
  }
  if (!/^\+977[0-9]{10}$/.test(phone)) {
    console.error(
      `Invalid phone "${phone}". Must be +977 followed by 10 digits, e.g. +9779812345678`,
    );
    process.exit(1);
  }

  const user = await prisma.user.upsert({
    where: { phoneNumber: phone },
    update: { role: 'super_admin', isActive: true },
    create: {
      phoneNumber: phone,
      fullName: name,
      role: 'super_admin',
      isVerified: true,
    },
    select: { id: true, phoneNumber: true, fullName: true, role: true },
  });

  console.log('✅ Super admin ready:');
  console.log(user);
  console.log(
    '\nLog in to the admin console with this phone number via the OTP flow.',
  );
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
