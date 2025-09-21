const { Client } = require('pg');

(async () => {
  const conn = process.env.DATABASE_URL || 'postgresql://postgres:postgres@127.0.0.1:54322/postgres';
  const client = new Client({ connectionString: conn });
  await client.connect();
  const res = await client.query("SELECT table_name FROM information_schema.tables WHERE table_schema='public' ORDER BY table_name;");
  console.log('tables in public schema:');
  for (const r of res.rows) console.log(' -', r.table_name);
  await client.end();
})();
