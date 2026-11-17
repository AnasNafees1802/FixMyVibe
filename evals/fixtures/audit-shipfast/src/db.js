const { Pool } = require('pg');

const pool = new Pool({ connectionString: process.env.DATABASE_URL });

async function query(text, params) {
  const result = await pool.query(text, params);
  return result.rows;
}

// Updates the given columns on one row.
async function update(table, id, fields) {
  const keys = Object.keys(fields);
  const sets = keys.map((key, i) => `${key} = $${i + 2}`).join(', ');
  await pool.query(`UPDATE ${table} SET ${sets} WHERE id = $1`, [id, ...keys.map((key) => fields[key])]);
}

module.exports = { query, update };
