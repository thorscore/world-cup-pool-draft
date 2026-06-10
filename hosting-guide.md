# Free hosting guide

The app is a single static file: `index.html`. That means it can be hosted for free without a server or database.

## Recommended: Netlify Drop

1. Go to https://app.netlify.com/drop
2. Drag the `index.html` file onto the page.
3. Netlify gives you a free public link.

This is the easiest option for a one-time pool.

## Also good: GitHub Pages

1. Create a free GitHub account.
2. Create a new repository.
3. Upload `index.html`.
4. In the repository settings, turn on Pages from the main branch.

This is better if you want to update the app later and keep a clean permanent link.

## Important note

The app saves data in each browser using local storage. To share the pool state with someone else, use **Export Pool** and send them the downloaded JSON file. They can use **Import Pool** to load it.

## Live result sync

The GitHub version includes an optional live result updater.

1. Create a free token at https://www.football-data.org/client/register
2. Open the GitHub repository.
3. Go to **Settings > Secrets and variables > Actions**.
4. Add a new repository secret named `FOOTBALL_DATA_TOKEN`.
5. Paste your football-data.org token.
6. Open **Actions > Update live World Cup results** and click **Run workflow**.

GitHub will then check for finished World Cup matches every 30 minutes. In the app, click **Sync Live Results** or turn on **Auto Sync**.
