const bcrypt = require('bcryptjs');

const ADMIN_USERNAME = process.env.ADMIN_USERNAME || 'admin';
const ADMIN_EMAIL    = process.env.ADMIN_EMAIL    || 'admin@admin.com';
const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD || 'admin123';

async function seedAdmin(User) {
  const existing = await User.findOne({ where: { username: ADMIN_USERNAME } });
  if (existing) {
    console.log(`Admin user "${ADMIN_USERNAME}" already exists, skipping seed.`);
    return;
  }

  const hashed = await bcrypt.hash(ADMIN_PASSWORD, global.cfg.bcrypt.saltRounds);
  await User.create({
    username: ADMIN_USERNAME,
    email:    ADMIN_EMAIL,
    password: hashed,
    isActive: true
  });

  console.log(`Admin user "${ADMIN_USERNAME}" created (email: ${ADMIN_EMAIL}).`);
}

module.exports = { seedAdmin };
