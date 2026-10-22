# Local WordPress on Windows (Laravel Herd)

A Valet-like setup for Windows 11: put a folder in `Sites` and it opens at `http://<folder>.test`.

| Part | What you get |
|---|---|
| Laravel Herd | Web server and PHP 8.3 (other versions per site with `herd isolate 8.4`). Same commands as Valet: `herd park/link/secure`. `valet` is aliased to `herd` |
| MySQL 8.4 | Windows service `MySQL84`, user `root`, no password, `127.0.0.1:3306` |
| WP-CLI | `wp` in Git Bash, `wp.bat` in PowerShell |
| PHP settings | 512M memory and upload limits; errors logged to `~/.config/herd/Log/php-errors.log` (`phplog` tails it) |
| Commands | `new-wp`, `del-wp`, `new-headless`, `del-headless`, `sync-hosts`, `check-dev`, `update-dev` |

## Install

1. Download this folder (ZIP from GitHub) and unzip it.
2. Open **PowerShell as Administrator**, go to the `windows-dev` folder and run:
   ```powershell
   Set-ExecutionPolicy -Scope Process Bypass
   .\setup.ps1
   ```
3. When it opens the Herd website, install Herd, open it once, then press Enter in PowerShell.
4. When it says `Done`, open **Git Bash** and run `check-dev`.

Options: `-SitesPath D:\Sites`, `-MySqlVersion 8.4.7` (if the default download is gone), `-InstallNvm`, `-SkipMySql`, `-SkipDefender`.
The script is safe to run again; it skips what's already done.

## Use

In Git Bash:

```bash
new-wp mysite                  # http://mysite.test, login admin / admin
new-wp shop --https            # https://shop.test
new-wp kund --locale sv_SE     # Swedish WordPress
del-wp mysite                  # delete the folder and its database
sync-hosts                     # make every folder in ~/Sites reachable at <folder>.test
```

Herd doesn't always add new folders to the Windows hosts file, so the browser says
"DNS address could not be found". `new-wp` and `del-wp` run `sync-hosts` for you (click **Yes** in the
Windows popup); run it yourself after adding a folder by hand.

Each site gets its own database named after the folder (`my-site` → `my_site`), with debug logging on
(`wp-content/debug.log`).

Any other folder you put in `~/Sites` is served too, e.g. a WordPress site you copy in by hand.

## Headless WordPress + Astro

```bash
new-headless blog              # WordPress at http://blog-cms.test + Astro in ~/Projects/blog
cd ~/Projects/blog && npm run dev   # http://localhost:4321, shows the WordPress posts and pages
npm run build                  # static HTML in dist/, upload to Netlify / Cloudflare Pages / GitHub Pages
del-headless blog              # remove both
```

Write content in WordPress, design the site in Astro (`src/layouts/Layout.astro`, `src/pages/`).
The template is in `templates/astro-wp`.

## Updating

`update-dev` downloads the latest commands and templates from GitHub into `~/bin` and `~/.windows-dev`.

## Notes
- **MySQL:** `net stop MySQL84` / `net start MySQL84`. Config `C:\MySQL\my.ini`, data `C:\MySQL\data`.
  To browse databases use HeidiSQL or TablePlus: `127.0.0.1`, port `3306`, user `root`, no password.
- **Uploads over 128 MB fail:** raise `client_max_body_size` in Herd's nginx config (`~/.config/herd/config/nginx/`) and restart Herd.
- **`$'\r': command not found`:** a script got Windows line endings. Fix it with `sed -i 's/\r$//' <file>`.
