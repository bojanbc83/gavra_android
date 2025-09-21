const { Client } = require('pg');

(async () => {
  try {
    // Use the pooler hostname and explicitly set TLS servername for SNI
    const client = new Client({
      host: 'aws-0-eu-central-1.pooler.supabase.com',
      port: 6543,
      user: 'postgres.gjtabtwudbrmfeyjiicu',
      password: '1DIA0obrDgQHGMAc',
      database: 'postgres',
      application_name: 'sqltest',
      ssl: {
        rejectUnauthorized: false,
        minVersion: 'TLSv1.2',
        servername: 'aws-0-eu-central-1.pooler.supabase.com'
      }
    });

    await client.connect();
    const res = await client.query('SELECT 1 AS result');
    console.log('Query result:', res.rows);
    await client.end();
  } catch (err) {
    console.error('Connection error:', err);
    process.exitCode = 2;
  }
})();
