'use strict';
// One SQLite connection for the app. Always pass values through `params`; never build SQL from strings.
const { DatabaseSync } = require('node:sqlite');

const db = new DatabaseSync(process.env.DB_FILE || ':memory:');
db.exec(`
  CREATE TABLE IF NOT EXISTS posts (
    id INTEGER PRIMARY KEY,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
  );
`);

/** Run a SELECT and return all rows. */
function query(sql, params = []) {
  return db.prepare(sql).all(...params);
}

/** Run an INSERT, UPDATE or DELETE. Returns { changes, lastInsertRowid }. */
function run(sql, params = []) {
  return db.prepare(sql).run(...params);
}

module.exports = { db, query, run };
