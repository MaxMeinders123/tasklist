# Project Atlas deploy package

Cheapest public hosting option: **GitHub Pages**

## Files
- `index.html` — the site
- `README.md` — deploy notes

## How to publish on GitHub Pages
1. Create a new GitHub repo.
2. Upload `index.html` to the repo root.
3. In repo settings, enable GitHub Pages from the default branch/root.
4. Wait for the public URL to appear.

## Password
The first version uses a simple client-side password gate (`atlas`).
That is fine for a private demo, but for real security you should move auth server-side later.
