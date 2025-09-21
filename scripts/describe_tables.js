const { Client } = require('pg');

(async () => {
  const conn = process.env.DATABASE_URL || 'postgresql://postgres:postgres@127.0.0.1:54322/postgres';
  const client = new Client({ connectionString: conn });
  await client.connect();
  const tables = ['mesecni_putnici','putovanja_istorija'];
  for (const t of tables) {
    console.log('\n--- TABLE: ' + t + ' ---');
    const res = await client.query(`SELECT column_name, data_type, is_nullable FROM information_schema.columns WHERE table_schema='public' AND table_name=$1 ORDER BY ordinal_position`, [t]);
    for (const row of res.rows) {
      console.log(`${row.column_name}\t| ${row.data_type}\t| ${row.is_nullable}`);
    }
  }
  await client.end();
})();
