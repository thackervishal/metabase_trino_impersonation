# Metabase + Trino connection impersonation demo

A minimal, throwaway local stack: Postgres (sample data) → Trino (query engine + file-based access control) → Metabase (connects only to Trino, never directly to Postgres).

## Setup

1. `cp .env.example .env` and fill in `MB_PREMIUM_EMBEDDING_TOKEN` (connection impersonation is a Metabase Enterprise feature and won't work without a valid trial/dev token).
2. `docker compose up -d`
3. Wait about a minute for Metabase to finish booting, then: `bash seed.sh`

All passwords are the same (`metabot1` by default, see `.env`) — this is a disposable local stack, not meant to hold anything sensitive.

## URLs and logins

| Service | URL |
|---|---|
| Metabase | http://localhost:3000 |
| Trino (coordinator UI / JDBC) | http://localhost:8080 |

| User | Email | Password | Group | Trino identity |
| --- | --- | --- | --- | --- |
| Admin | admin@example.com | metabot1 | Administrators | — |
| Leo | leo@example.com | metabot1 | Sales Team (impersonated) | `leo` |
| Mikey | mikey@example.com | metabot1 | Sales Team (impersonated) | `mikey` |
| Ralph | ralph@example.com | metabot1 | Analytics Team (**not** impersonated) | none — runs as `trino_super` |
| Donny | donny@example.com | metabot1 | Analytics Team (**not** impersonated) | none — runs as `trino_super` |

Ports and passwords come from `.env` — the values above are the defaults in `.env.example`; if you changed them, use your own values instead.
To log into the Trino admin UI, use username `trino_super` and no password. Also, when looking at the query history on the Trino dashboard, remember to add "Finished" queries to the default filter.

## What gets created

- **Sales Team** group — data permission set to: View data = Impersonation on `trino_test`, using the `trino_user` attribute. Ensure all users in this group have the `trino_user` attribute set to the Trino identity they'll assume.
  - Leo → sees `people` rows for `TX, CA, NY, GA` only, real email, `birth_date` redacted.
  - Mikey → sees `people` rows for `MT, IA, MN, WI` only, masked email, real `birth_date`.
  - Both are denied every other table (e.g. `accounts`) outright.
- **Analytics Team** group — data permission set to: View data = Unrestricted on `trino_test`, **no** user attribute at all. Because their group's access is more permissive than any impersonation policy, Metabase never attempts impersonation for them — their queries just run as the base `trino_super` connection, seeing everything. Any restrictions needed for un-impersonated users can be added in Metabase's own permissions system instead (e.g. whether they have SQL access at all) — impersonation itself won't apply.
- **All Users** (the implicit group everyone belongs to) is explicitly set to **Blocked** on `trino_test` — required so it doesn't override the Sales Team's impersonation restriction (Metabase always grants the most permissive access across a person's groups).

## Demo/Test

[Watch an End to End Demo](https://youtu.be/1-9eCV3QsCc)

- Log in as admin to Metabase, browse around, see the groups, the users, the user attributes, the permissions (data perms), etc.
- Then log in to Metabase as Leo (in an incognito/other browser):
  - Open the `accounts` table in Metabase.
    - You should get an error from Trino saying no permission.
    - In the Trino UI, check the query history — you should see the query log coming in as `leo`, not `trino_super`, showing impersonation is in effect.
  - Open the `people` table in Metabase.
    - You should see just the states Leo is allowed to see, with the data masked appropriately per the rules set up for him.
    - In Trino you should see his query come in as `leo`, and in the query details, an additional comment highlighting his Metabase user id.
- Log in as Donny in another incognito window:
  - He is not impersonated, and has no in-Metabase data restrictions either, so he should be able to click any table and see all data.
  - In Trino's logs, his queries should come in as `trino_super`.

## Editing the access-control rules

`trino/access-control/rules.json` is Trino's file-based access-control policy — it's what actually enforces the row filters, column masks, and table grants once Metabase asks Trino to impersonate someone. Trino re-reads this file every ~5 seconds (`security.refresh-period` in `trino/etc/access-control.properties`), so edits take effect without restarting anything.

## Re-running

`seed.sh` is not idempotent — running it twice will fail on the group-creation step (or create duplicate groups) since it doesn't check for existing state first. For a clean slate: `docker compose down -v && docker compose up -d`, wait for Metabase, then `bash seed.sh` again.
