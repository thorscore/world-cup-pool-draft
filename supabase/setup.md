# Supabase live draft setup

Use this when you want live drafting, player-only links, and spectator access.

## 1. Create the Supabase project

1. Go to https://supabase.com
2. Create a free account or sign in.
3. Create a new project.
4. Wait for the project to finish provisioning.

## 2. Install the database schema

1. In Supabase, open **SQL Editor**.
2. Open `supabase/schema.sql` from this repository.
3. Paste the full SQL into the editor.
4. Click **Run**.

This creates the pool tables and protected functions used by the app.

## 3. Add the public app config

1. In Supabase, go to **Project Settings > API**.
2. Copy the **Project URL**.
3. Copy the **anon public** key.
4. Edit `config.js` in this repository.
5. Paste those values:

```js
window.WC_POOL_CONFIG = {
  supabaseUrl: "https://your-project.supabase.co",
  supabaseAnonKey: "your-anon-public-key"
};
```

The anon key is designed to be public. Admin powers are controlled by private room access keys and the SQL functions.

## 4. Create a live room

1. Open the app.
2. Add the pool players in **Setup**.
3. Open **Room**.
4. Click **Create Live Room**.
5. Copy the generated player links and send each person their own link.

## Access levels

- Admin link: setup, draft control, scoring, results, live score sync, reset.
- Player link: view the pool and pick only when it is that player's turn.
- Spectator link: view only.
