const jwt = require('jsonwebtoken');

const JWT_SECRET = process.env.JWT_SECRET || 'shipfast-dev-secret';

function signToken(user) {
  return jwt.sign({ id: user.id, role: user.role }, JWT_SECRET, { expiresIn: '30d' });
}

function requireAuth(req, res, next) {
  const header = req.headers.authorization || '';
  try {
    req.user = jwt.verify(header.replace('Bearer ', ''), JWT_SECRET);
    next();
  } catch (err) {
    res.status(401).json({ error: 'Unauthorized' });
  }
}

module.exports = { requireAuth, signToken };
