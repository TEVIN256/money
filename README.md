# Budget

Personal monthly budget in SAR and UGX. Single `index.html`, hosted on GitHub Pages at money.bashari.tech, data in a personal Supabase project behind email login.

- `schema.sql` — tables + Row Level Security (each login only sees its own rows). Paste into the Supabase SQL editor; idempotent, append new numbered blocks.
- `.github/workflows/keepalive.yml` — pings the database twice a week so the free project doesn't pause.
- No figures live in this repo; they're only in Supabase.
