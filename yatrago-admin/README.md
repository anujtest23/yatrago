# YatraGo Admin Console

Web dashboard for administering the YatraGo platform. Talks to the NestJS API
(`yatrago-api`) — no Postman or DB access required.

## Stack

React 18 · Vite 6 · TypeScript · Tailwind CSS v4 · React Router · Axios

## Getting started

```bash
cd yatrago-admin
npm install
npm run dev        # http://localhost:5174
```

The dev server proxies `/api` and `/uploads` to the backend
(`http://localhost:3000` by default). Point it elsewhere with:

```bash
VITE_API_TARGET=http://your-api-host:3000 npm run dev
```

Make sure the API is running (`cd yatrago-api && npm run start:dev`).

## Logging in

Auth is phone-OTP, same as the mobile app. Sign in with a phone number listed
in the backend's `ADMIN_PHONES` env var — the console verifies admin rights
before letting you in. In development the backend returns the OTP in the
response, and the login screen displays it for convenience.

## Features

| Area                 | Actions |
|----------------------|---------|
| Dashboard            | Live KPIs — users, drivers, trips, revenue, bookings |
| Users                | Search, block, credit wallet |
| Driver Verification  | Review documents, approve / reject |
| Vehicles             | Review documents, approve / reject |
| Trips                | Monitor, force-cancel, override price |
| Bookings             | Monitor all bookings |
| Payouts              | Approve / reject (with wallet refund) |
| SOS Alerts           | Acknowledge / resolve, view location |
| Reports              | Update status, moderate ratings |
| Settings             | Edit platform business-rule config |
| Audit Logs           | Full admin action history |

## Build

```bash
npm run build      # type-checks then emits static files to dist/
```

Serve `dist/` behind any static host; proxy `/api` and `/uploads` to the API.

## Backend gaps noted while building

These admin capabilities have no API yet, so they are not in the UI:

- Wallet **deduction** (only credit exists — `POST /admin/wallets/:id/credit`).
- Wallet **transaction listing** for monitoring per-user account activity.
- A **ratings list** endpoint (moderation is by rating ID only).
