# C3A: Custom Automation Script — Write-Up

**Name:** Nelson Ngumo
**Course:** AfricaHackon Academy — Cohort 6

## What the script does

`script.sh` automates four of the five listed tasks in a single run: **system maintenance** (checks root disk usage against an 80% threshold and deletes log files older than 7 days from a logs directory), **file organization** (loops through a "incoming" folder and moves any `.txt`/`.log` files into an "organized" folder), **scheduled cleanup** (clears out all temporary files from a `tmp` directory every time the script executes), and **backup automation** (copies files from an "important" folder into a new timestamped subfolder under `backups/`, e.g. `backup_20260707_163821`). Before touching anything, it prints a system notification (`"System will reboot soon"`) and, as a bonus feature, prompts the user with `read -p "Do you want to continue... (y/n)"` — if the user answers "n", the script exits safely without making any changes. It also displays a simple text-based progress bar during the longer steps as a second bonus feature. Every action (disk usage readings, files deleted/moved/backed up, user decisions) is timestamped and written to `/home/$USER/script_log.txt` via a shared `log_action()` function, so there's a full audit trail of everything the script did on a given run.

## How I tested it

I built a self-contained sandbox under `~/c3a_workspace/` (with `logs/`, `incoming/`, `tmp/`, `important/`, `organized/`, and `backups/` subfolders) so the script could be safely tested without touching real system files. I seeded it with a mix of test data: an old log file backdated 10 days (to confirm the 7-day deletion logic), a fresh log file (to confirm it's *not* deleted), sample `.txt`/`.log` files to organize, dummy `.tmp` junk files, and two "important" files to back up. I ran the script three times: once accepting the prompt (`y`) to confirm all four tasks executed correctly and logged properly; once declining the prompt (`n`) to confirm it exits safely with no changes; and once more after the sandbox was already clean, to confirm the script degrades gracefully (e.g., "No logs older than 7 days found") instead of throwing errors when there's nothing to do. I checked `script_log.txt` after each run to verify the log entries matched what actually happened on disk.

## Challenges faced

The main challenge was making the script safe to test repeatedly without a real "old" file lying around — I solved this using `touch -d "10 days ago"` to backdate a test log file so the `find -mtime +7` logic had something realistic to act on. I also had to guard the file-organization loop against Bash's default globbing behavior, where `*.txt *.log` would literally pass through as unexpanded strings if no matching files existed; adding an `if [ -f "$file" ]` check inside the loop fixed that and let the script report "no files found" cleanly instead of trying to move a non-existent file. Finally, I made sure destructive actions (log deletion, temp cleanup) were gated behind the `read -p` confirmation prompt so the script can't silently delete anything without explicit user consent.
