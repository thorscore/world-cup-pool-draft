# World Cup Pool Draft

A free, static web app for running a 2026 World Cup draft pool.

## Features

- Up to 12 pool members
- Snake draft with 4 teams per person
- Editable 2026 World Cup team list
- Editable points by round
- Win and tie scoring
- Automatic leaderboard
- Export/import pool data
- Optional live result sync from football-data.org
- Optional live draft rooms with player-only links through Supabase

## Hosting

This app is only `index.html`, so it can run on GitHub Pages, Netlify, or any static host.

For GitHub Pages, publish from the repository root and open the Pages URL.

## Optional live results

The app can sync finished match results from football-data.org through GitHub Actions.

1. Create a free API token at https://www.football-data.org/client/register
2. In GitHub, open this repository.
3. Go to **Settings > Secrets and variables > Actions > New repository secret**.
4. Name the secret `FOOTBALL_DATA_TOKEN`.
5. Paste the token as the secret value.
6. Go to **Actions > Update live World Cup results > Run workflow** once.

After that, GitHub checks for finished matches every 30 minutes and publishes `live-results.json`. In the app, use **Sync Live Results** or turn on **Auto Sync**.

## Optional live draft rooms

For live drafting and limited player access, use the Supabase setup:

1. Create a free Supabase project.
2. Run `supabase/schema.sql` in the Supabase SQL Editor.
3. Add the project URL and anon public key to `config.js`.
4. Open the app, add players, then create the room from the **Room** tab.

Full steps are in `supabase/setup.md`.
