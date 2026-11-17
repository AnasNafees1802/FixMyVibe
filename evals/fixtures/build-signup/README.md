# Pondlog

A small field-notes site built on the Node standard library. No framework and no dependencies.

- `server.js` routes requests. `lib/db.js` owns the SQLite connection, `lib/http.js` the response
  and body helpers, `lib/validate.js` the input checks.
- `public/styles.css` holds the design tokens. Pages read every color, font and space from them.
- Run it with `npm start`, test it with `npm test`.
