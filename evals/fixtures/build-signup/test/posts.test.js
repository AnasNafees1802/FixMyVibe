'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { createServer } = require('../server');
const { run } = require('../lib/db');
const { isEmail, clampText } = require('../lib/validate');

function listen() {
  return new Promise((resolve) => {
    const server = createServer().listen(0, () => resolve({ server, base: `http://127.0.0.1:${server.address().port}` }));
  });
}

test('isEmail accepts a normal address and rejects junk', () => {
  assert.equal(isEmail('ada@example.org'), true);
  assert.equal(isEmail('not-an-email'), false);
  assert.equal(isEmail(42), false);
});

test('clampText trims and cuts', () => {
  assert.equal(clampText('  hello  ', 3), 'hel');
  assert.equal(clampText(null, 3), '');
});

test('GET /api/posts returns posts and caps the limit', async () => {
  run('INSERT INTO posts (title, body) VALUES (?, ?)', ['Heron at dawn', 'Stood for an hour.']);
  const { server, base } = await listen();
  try {
    const res = await fetch(`${base}/api/posts?limit=9999`);
    assert.equal(res.status, 200);
    const { posts } = await res.json();
    assert.ok(posts.length >= 1 && posts.length <= 50);
    assert.equal(posts[0].title, 'Heron at dawn');
  } finally {
    server.close();
  }
});

test('unknown route returns 404 JSON', async () => {
  const { server, base } = await listen();
  try {
    const res = await fetch(`${base}/nope`);
    assert.equal(res.status, 404);
  } finally {
    server.close();
  }
});
