# Untitled Slayers — New PC recovery

**Do not wipe the original PC until the final Studio place and custom plugin are backed up somewhere off-device.**

## What is in GitHub already
- Repository: https://github.com/Pancakes-Lol/Untitled-Slayers, branch `main`.
- Current Rojo scripts, configs, player saving, stats, combat, enemy overheads, UI controllers, quest logic, and `rojo.exe`.
- `default.project.json` and earlier exported Roblox Studio place snapshots.
- **The repo is not a complete replacement for the latest Roblox Studio place or locally installed custom plugins.**

## On the OLD PC: required before wiping
1. Open **the latest Untitled Slayers place** in Roblox Studio. Use **File → Save to File** and save `UntitledSlayers-FINAL-Backup.rbxl` inside `Desktop\Untitled Slayers`. Verify it exists in File Explorer. Also use **File → Publish to Roblox** for the correct experience.
2. In Studio use **Plugins → Untitled Slayers → Sync Snapshot** if the custom snapshot tool is working. This is an extra archive; it does not replace the full `.rbxl`.
3. Back up the **entire** folder `C:\Users\Administrator\Desktop\Untitled Slayers` to an external USB drive or a synced cloud folder. Include the hidden `.git` directory, `rojo.exe`, place files and any local changes. Run `git status` and push legitimate source changes if any exist.
4. Back up the **entire** `%LOCALAPPDATA%\Roblox\Plugins` folder. This is where locally saved Studio plugins usually live; it includes the custom snapshot plugin if it was saved as a local plugin. The folder is not automatically included in a GitHub clone.
5. If available, preserve `%LOCALAPPDATA%\Roblox\RobloxStudio\AutoSaves` as a fallback.
6. Confirm the backup is visible **off the old PC**. For OneDrive use a web browser to verify upload finished. For USB, safely eject and reconnect it. Do not wipe before this check.

## On the NEW PC
1. Install Git and Roblox Studio; sign into the **same Roblox account** for the published place, saved progress and DataStores.
2. Restore the folder to `Desktop\Untitled Slayers`, or clone `https://github.com/Pancakes-Lol/Untitled-Slayers.git` and put the latest backed-up `.rbxl` in the clone.
3. Install the **Rojo Studio plugin**. Copy backed-up local plugin files to `%LOCALAPPDATA%\Roblox\Plugins`. Restart Studio to load the custom **Untitled Slayers → Sync Snapshot** plugin.
4. Open `UntitledSlayers-FINAL-Backup.rbxl` (or the correct Roblox cloud-published experience) in Studio.
5. In the repo folder run `git pull`; in a terminal in the repo folder run `.\rojo.exe serve`. In Studio connect Rojo to `localhost:34872`.
6. Verify Studio-only maps/models, enemy templates, custom GUI assets, Tetsu, quest tracking, stats, gems, saving, combat and custom plugin.

**Note:** Actual Roblox DataStore progress is server-side on Roblox, attached to the right experience and account, not in the local repo. Don't put passwords or access tokens in a public GitHub repository.

## Essential path references
- Local repo (old PC): `C:\Users\Administrator\Desktop\Untitled Slayers`
- Local plugins: `%LOCALAPPDATA%\Roblox\Plugins`
- Studio autosaves: `%LOCALAPPDATA%\Roblox\RobloxStudio\AutoSaves`
- Main branch: `Pancakes-Lol/Untitled-Slayers`
