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
