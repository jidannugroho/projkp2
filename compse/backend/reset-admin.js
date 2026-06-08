import bcrypt from 'bcryptjs';
import pkg from 'pg';
import dotenv from 'dotenv';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
dotenv.config({ path: path.join(__dirname, '.env') });

const { Pool } = pkg;

const pool = new Pool({
   connectionString:
      process.env.DATABASE_URL ||
      'postgres://postgres:postgres@localhost:5432/aset_sekolah',
});

async function resetPassword() {
   const email = 'admin@sekolah.com';
   const password = 'test123';
   const salt = await bcrypt.genSalt(12);
   const hash = await bcrypt.hash(password, salt);

   try {
      console.log('Connecting to database...');
      console.log('Database URL:', process.env.DATABASE_URL);

      // Check if user exists
      const checkRes = await pool.query(
         'SELECT id FROM users WHERE email = $1',
         [email],
      );

      if (checkRes.rows.length > 0) {
         // Update existing user
         const res = await pool.query(
            'UPDATE users SET password_hash = $1 WHERE email = $2 RETURNING id',
            [hash, email],
         );
         console.log(`✅ Password for ${email} has been reset to: ${password}`);
         console.log(`User ID: ${res.rows[0].id}`);
      } else {
         // Create new user
         console.log(`User ${email} not found. Creating user...`);
         const newUser = await pool.query(
            'INSERT INTO users (email, password_hash, role, is_active) VALUES ($1, $2, $3, $4) RETURNING id',
            [email, hash, 'superadmin', true],
         );

         const userId = newUser.rows[0].id;

         // Create profile
         await pool.query(
            'INSERT INTO profiles (user_id, display_name, position, department) VALUES ($1, $2, $3, $4)',
            [userId, 'Super Admin', 'System Administrator', 'IT Department'],
         );

         console.log(
            `✅ User ${email} created successfully with password: ${password}`,
         );
         console.log(`User ID: ${userId}`);
      }
   } catch (err) {
      console.error('❌ Error:', err.message);
      console.error('Stack:', err.stack);
      process.exit(1);
   } finally {
      await pool.end();
      process.exit(0);
   }
}

resetPassword();
