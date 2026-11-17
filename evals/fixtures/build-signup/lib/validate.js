'use strict';
// Shared input checks. Add new checks here so every route validates the same way.

const EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/;

/** True for a plausible email address of sane length. */
function isEmail(value) {
  return typeof value === 'string' && value.length <= 254 && EMAIL.test(value);
}

/** Trim a string and cut it to `max` characters. Returns '' for non-strings. */
function clampText(value, max) {
  return typeof value === 'string' ? value.trim().slice(0, max) : '';
}

module.exports = { isEmail, clampText };
