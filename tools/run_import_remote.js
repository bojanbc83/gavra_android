const fs = require('fs');
const { Client } = require('pg');

(async () => {
  let client;
  try {
    const conn = process.env.IMPORT_CONN || process.argv[2];
    if (!conn) {
      console.error('Provide connection string as ENV IMPORT_CONN or arg');
      process.exit(2);
    }

    client = new Client({
      connectionString: conn,
      ssl: { rejectUnauthorized: false }
    });
    await client.connect();
    console.log('Connected successfully');

    // 1) Read import SQL
    const importSql = fs.readFileSync(__dirname + '/../tmp/import_dozvoljeni.sql', 'utf8');
    const mappingSql = fs.readFileSync(__dirname + '/../tmp/mapping_putovanja_safe.sql', 'utf8');

    // 2) Start transaction
    await client.query('BEGIN');
    console.log('BEGIN transaction');

    // 3) Run import - execute statements sequentially
    const importStatements = importSql.split(/;\s*\n/).map(s => s.trim()).filter(Boolean);
    for (const stmt of importStatements) {
      await client.query(stmt + ';');
    }
    console.log('Import statements executed:', importStatements.length);

    // 4) Run safe mapping
    const mappingStatements = mappingSql.split(/;\s*\n/).map(s => s.trim()).filter(Boolean);
    for (const stmt of mappingStatements) {
      await client.query(stmt + ';');
    }
    console.log('Mapping statements executed:', mappingStatements.length);

    // 5) Verify - count newly inserted rows by checking created_at within last 5 minutes
    const res = await client.query("SELECT COUNT(*) FROM public.dozvoljeni_mesecni_putnici WHERE created_at >= now() - interval '10 minutes';");
    console.log('Inserted rows (approx):', res.rows[0].count);

    // Commit
    await client.query('COMMIT');
    console.log('COMMIT successful');

    await client.end();
  } catch (err) {
    console.error('Error during remote import:', err);
    try {
      // try rollback if possible
      if (client) await client.query('ROLLBACK');
    } catch (rbErr) {
      console.error('Rollback failed:', rbErr);
    }
    process.exit(3);
  }
})();
