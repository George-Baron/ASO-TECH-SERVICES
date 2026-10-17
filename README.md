# ASO-TECH SERVICES

Business app (POS, purchasing, inventory, deliveries, returns, accounting) hosted on GitHub Pages with a shared Supabase database.

## Files (upload ALL of them to the root of your GitHub repository)
| File | What it is |
|---|---|
| `index.html` | The whole app |
| `config.js` | Your Supabase project URL + public (anon) key. Already filled in. |
| `supabase.js`, `591.supabase.js` | Supabase's own browser library (served from your site, no outside dependency) |
| `supabase_setup.sql` | Creates the database tables and security rules (run once in Supabase) |
| `.nojekyll` | Tells GitHub Pages to serve the files as they are |

## Go live
1. **Create the database tables.** Supabase dashboard -> *SQL Editor* -> *New query* -> paste everything from `supabase_setup.sql` -> *Run*. It should say "Success. No rows returned".
2. **Turn off email confirmation.** Supabase -> *Authentication* -> *Sign In / Providers* -> *Email* -> switch **Confirm email** OFF -> Save. (The app signs staff in with usernames, not real emails, so there is no inbox to confirm from.)
3. **Upload the files** to your GitHub repository (Add file -> Upload files), replacing the old `index.html`, then *Commit changes*. Wait about a minute for GitHub Pages to update.
4. **Open your site.** The first screen asks you to create the administrator. Do this straight away, before sharing the link.

Then add staff under **Settings -> Users & roles** (username, password, role, branch).

## How it behaves
* **Shared data.** Every change is saved to Supabase and other devices pick it up within about 20 seconds (or press *Settings -> My account -> Sync now*). The header says "online · saved" when everything is stored.
* **Works offline.** If the internet drops, the app keeps working and uploads when it is back.
* **Existing local data is uploaded** the first time someone signs in on a browser that already holds data from the old version. Sign in on the browser that has your real data first.
* **Document numbers** include a two-character device code (e.g. `POS-MAIN-K7-0001`) so two tills never create the same number.
* **Security.** Logins and branch separation are enforced by the database: branch staff cannot read or write other branches' records, and only administrators can change settings and branches. Role permissions inside a branch (who may approve refunds, post journals, and so on) are enforced by the app, not the database.
* **Passwords.** Staff change their own under *Settings -> My account*. To reset someone else's, delete their login in Supabase -> Authentication -> Users and create the user again in the app (use a new username, or disable the old one).
* **Backups.** Restore and Erase are switched off in cloud mode so nobody can overwrite everyone's data. Use Supabase's backups. The free plan pauses projects after a week of no activity.
* **Updating the app later.** Replace `index.html` only.

## Keys
`config.js` contains the *anon* key, which is designed to be public. Never put the `service_role` / secret key in any file in this repository.
