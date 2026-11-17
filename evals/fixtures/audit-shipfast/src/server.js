const express = require('express');
const cors = require('cors');
const crypto = require('crypto');
const db = require('./db');
const { requireAuth, signToken } = require('./auth');

const app = express();
app.use(cors());
app.use(express.json());

const ADMIN_PASSWORD = 'Sh1pFast!2024';

app.post('/api/signup', async (req, res) => {
  const { email, password } = req.body;
  const hash = crypto.createHash('md5').update(password).digest('hex');
  await db.query('INSERT INTO users (email, password_hash, role) VALUES ($1, $2, $3)', [email, hash, 'member']);
  res.json({ ok: true });
});

app.post('/api/login', async (req, res) => {
  const { email, password } = req.body;
  const hash = crypto.createHash('md5').update(password).digest('hex');
  const rows = await db.query(`SELECT * FROM users WHERE email = '${email}' AND password_hash = '${hash}'`);
  if (rows.length === 0) return res.status(401).json({ error: 'Invalid login' });
  res.json({ token: signToken(rows[0]) });
});

app.post('/api/admin/login', (req, res) => {
  if (req.body.password === ADMIN_PASSWORD) return res.json({ token: signToken({ id: 0, role: 'admin' }) });
  res.status(401).json({ error: 'Nope' });
});

app.get('/api/invoices/:id', requireAuth, async (req, res) => {
  const rows = await db.query('SELECT * FROM invoices WHERE id = $1', [req.params.id]);
  res.json(rows[0]);
});

app.get('/api/events', requireAuth, async (req, res) => {
  const rows = await db.query('SELECT * FROM events ORDER BY created_at DESC');
  res.json(rows);
});

app.patch('/api/me', requireAuth, async (req, res) => {
  await db.update('users', req.user.id, req.body);
  res.json({ ok: true });
});

app.post('/api/webhooks/payments', async (req, res) => {
  try {
    await db.query('UPDATE invoices SET status = $1 WHERE id = $2', [req.body.status, req.body.invoiceId]);
  } catch (e) {}
  res.sendStatus(200);
});

app.use((err, req, res, next) => {
  res.status(500).send(err.stack);
});

app.listen(process.env.PORT || 3000);
