# Salary Management frontend

React + TypeScript application built with Vite, Material UI, and React Router. Use Node 22.14.0 from the repository `.nvmrc`.

```sh
npm install
npm run dev
npm test
npm run build
```

The development server proxies `/api` to `http://127.0.0.1:3000` by default. Start the Rails API on that address, or set `RAILS_API_ORIGIN` to another Rails origin before starting Vite. Production is expected to serve the SPA and API from the same HTTPS origin; deployment integration is not part of this frontend slice.

Authentication uses the Rails server-side session cookie. The client bootstraps through `GET /api/v1/session`, keeps the returned CSRF token in memory, and sends it in `X-CSRF-Token` for state-changing requests. It does not persist tokens in browser storage.
