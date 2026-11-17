'use strict';
// Pondlog: a tiny field-notes site. No framework, no dependencies.
const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const { query } = require('./lib/db');
const { sendJson } = require('./lib/http');

const PUBLIC_DIR = path.join(__dirname, 'public');
const STATIC = { '/': ['index.html', 'text/html; charset=utf-8'], '/styles.css': ['styles.css', 'text/css; charset=utf-8'] };

function createServer() {
  return http.createServer((req, res) => {
    const url = new URL(req.url, 'http://localhost');

    if (req.method === 'GET' && STATIC[url.pathname]) {
      const [file, type] = STATIC[url.pathname];
      res.writeHead(200, { 'Content-Type': type });
      fs.createReadStream(path.join(PUBLIC_DIR, file)).pipe(res);
      return;
    }

    if (req.method === 'GET' && url.pathname === '/api/posts') {
      const limit = Math.min(Number(url.searchParams.get('limit')) || 20, 50);
      const posts = query('SELECT id, title, body, created_at FROM posts ORDER BY created_at DESC LIMIT ?', [limit]);
      sendJson(res, 200, { posts });
      return;
    }

    sendJson(res, 404, { error: 'Not found' });
  });
}

if (require.main === module) {
  const port = Number(process.env.PORT) || 3000;
  createServer().listen(port, () => console.log(`Pondlog listening on http://localhost:${port}`));
}

module.exports = { createServer };
