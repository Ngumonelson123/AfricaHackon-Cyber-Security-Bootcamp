#!/usr/bin/env python3
"""
recon_automation.py
--------------------
AfricaHackon Academy - Cohort 6 (Squad 5)
Author: Nelson Ngumo

Assignment: Python Scripting - Create a Custom Python Automation Script

What it does
------------
Given a target domain, this script:
  1. Runs subfinder to passively enumerate subdomains for that domain and
     saves the raw list to <domain>.txt.
  2. Feeds that list into httpx to probe which of those subdomains are
     actually live (responding over HTTP/HTTPS), saving the live ones to
     <domain>_live.txt.
  3. (Optional/bonus) Sends a real-time notification to a Discord webhook
     with a short summary once the run finishes.

Why two separate binaries are located explicitly
--------------------------------------------------
On a plain Ubuntu box (not Kali), `subfinder` and ProjectDiscovery's `httpx`
aren't preinstalled, and once you `go install` them they land in
`$(go env GOPATH)/bin`. That directory is often NOT the first `httpx` found
on PATH -- the Python "httpx" HTTP client package also installs a CLI
command literally called `httpx` (a completely different tool: an HTTP
client, not a subdomain prober -- try `pip show httpx`). Blindly calling
"httpx" via subprocess can silently invoke the wrong program. To avoid that,
resolve_tool() below actively prefers the Go-installed binaries and verifies
whichever binary it picks actually behaves like the ProjectDiscovery tool
before trusting it.

Usage
-----
    python3 recon_automation.py -d vulnweb.com
    python3 recon_automation.py -d example.com -o ./results
    python3 recon_automation.py -d example.com --discord-webhook "https://discord.com/api/webhooks/..."

CLI Arguments
-------------
    -d / --domain           Target domain to enumerate (required)
    -o / --output-dir       Directory to write <domain>.txt / <domain>_live.txt
                             (default: current directory)
    --subfinder-path        Explicit path to the subfinder binary (optional)
    --httpx-path             Explicit path to the (ProjectDiscovery) httpx binary (optional)
    --discord-webhook        Discord webhook URL for a completion notification (optional, bonus)
    --timeout                Per-subprocess timeout in seconds (default: 300)

Exit codes
----------
    0  success
    1  fatal error (bad args, subfinder/httpx not found, subfinder run failed, etc.)
"""

import argparse
import os
import shutil
import subprocess
import sys
import urllib.request
import json


def log(message: str) -> None:
    """Print a timestamped progress message so the user can follow along."""
    print(f"[recon_automation] {message}")


def resolve_tool(explicit_path: str, tool_name: str, verify_flag: str) -> str:
    """
    Work out which binary on this machine is genuinely the tool we want.

    We check, in order:
      1. An explicit path passed on the CLI (--subfinder-path / --httpx-path).
      2. $(go env GOPATH)/bin/<tool_name> -- where `go install` puts things.
      3. Whatever `shutil.which(tool_name)` finds on PATH.

    For httpx specifically, candidate (3) is dangerous: the Python "httpx"
    HTTP-client package also ships a CLI called `httpx`. We guard against
    that by running `<candidate> -h` and checking the help text contains a
    flag string (verify_flag) that only ProjectDiscovery's tool has
    (e.g. "-silent"). If a candidate fails that check, we skip it and keep
    looking rather than trusting it blindly.
    """
    candidates = []
    if explicit_path:
        candidates.append(explicit_path)

    try:
        gopath = subprocess.run(
            ["go", "env", "GOPATH"], capture_output=True, text=True, timeout=10
        ).stdout.strip()
        if gopath:
            candidates.append(os.path.join(gopath, "bin", tool_name))
    except (FileNotFoundError, subprocess.SubprocessError):
        pass  # go not installed / not on PATH -- fine, we just skip this candidate

    on_path = shutil.which(tool_name)
    if on_path:
        candidates.append(on_path)

    for candidate in candidates:
        if not candidate or not os.path.isfile(candidate) or not os.access(candidate, os.X_OK):
            continue
        try:
            result = subprocess.run(
                [candidate, "-h"], capture_output=True, text=True, timeout=10
            )
            help_text = (result.stdout or "") + (result.stderr or "")
            if verify_flag in help_text:
                return candidate
            else:
                log(f"Skipping '{candidate}' -- does not look like the real {tool_name} "
                    f"(missing '{verify_flag}' in its help output; likely a different "
                    f"program with the same name on PATH).")
        except (subprocess.SubprocessError, OSError):
            continue

    return ""  # nothing usable found


def run_subfinder(subfinder_bin: str, domain: str, output_file: str, timeout: int) -> bool:
    """Run subfinder against `domain`, writing raw subdomains to `output_file`."""
    log(f"Enumerating subdomains for '{domain}' with subfinder ...")
    cmd = [subfinder_bin, "-d", domain, "-o", output_file, "-silent"]
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
    except subprocess.TimeoutExpired:
        log(f"ERROR: subfinder timed out after {timeout}s.")
        return False
    except OSError as exc:
        log(f"ERROR: could not run subfinder ({exc}).")
        return False

    if result.returncode != 0:
        log(f"ERROR: subfinder exited with code {result.returncode}.")
        if result.stderr.strip():
            log(f"subfinder stderr: {result.stderr.strip()}")
        return False

    if not os.path.isfile(output_file):
        log("ERROR: subfinder reported success but produced no output file.")
        return False

    return True


def run_httpx(httpx_bin: str, input_file: str, output_file: str, timeout: int) -> bool:
    """Probe every host in `input_file` with httpx, writing live hosts to `output_file`."""
    log("Probing discovered subdomains for live hosts with httpx ...")
    cmd = [httpx_bin, "-l", input_file, "-o", output_file, "-silent"]
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
    except subprocess.TimeoutExpired:
        log(f"ERROR: httpx timed out after {timeout}s.")
        return False
    except OSError as exc:
        log(f"ERROR: could not run httpx ({exc}).")
        return False

    if result.returncode != 0:
        log(f"ERROR: httpx exited with code {result.returncode}.")
        if result.stderr.strip():
            log(f"httpx stderr: {result.stderr.strip()}")
        return False

    return True


def count_lines(path: str) -> int:
    """Count non-empty lines in a file; returns 0 if the file doesn't exist or is empty."""
    if not os.path.isfile(path):
        return 0
    with open(path, "r", encoding="utf-8", errors="ignore") as f:
        # A loop + conditional: skip blank lines while counting real entries.
        count = 0
        for line in f:
            if line.strip():
                count += 1
        return count


def send_discord_notification(webhook_url: str, domain: str, total: int, live: int) -> None:
    """
    Bonus: POST a short completion summary to a Discord webhook.
    Failure here is never fatal -- recon results are already saved to disk
    by the time this runs, so a broken webhook shouldn't undo that work.
    """
    payload = {
        "content": (
            f"**Recon complete for `{domain}`**\n"
            f"Subdomains found: {total}\n"
            f"Live hosts: {live}"
        )
    }
    try:
        req = urllib.request.Request(
            webhook_url,
            data=json.dumps(payload).encode("utf-8"),
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        with urllib.request.urlopen(req, timeout=10) as resp:
            if 200 <= resp.status < 300:
                log("Discord notification sent.")
            else:
                log(f"Discord notification returned HTTP {resp.status} (non-fatal).")
    except Exception as exc:  # noqa: BLE001 - deliberately broad: a notification failure must never crash the run
        log(f"Could not send Discord notification (non-fatal): {exc}")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Enumerate subdomains with subfinder and probe them for live hosts with httpx."
    )
    parser.add_argument("-d", "--domain", required=True, help="Target domain, e.g. vulnweb.com")
    parser.add_argument("-o", "--output-dir", default=".", help="Directory to write result files into")
    parser.add_argument("--subfinder-path", default="", help="Explicit path to the subfinder binary")
    parser.add_argument("--httpx-path", default="", help="Explicit path to the (ProjectDiscovery) httpx binary")
    parser.add_argument("--discord-webhook", default="", help="Discord webhook URL for a completion notification")
    parser.add_argument("--timeout", type=int, default=300, help="Per-tool subprocess timeout in seconds")
    args = parser.parse_args()

    domain = args.domain.strip().lower()
    if not domain:
        log("ERROR: domain cannot be empty.")
        return 1

    try:
        os.makedirs(args.output_dir, exist_ok=True)
    except OSError as exc:
        log(f"ERROR: could not create output directory '{args.output_dir}': {exc}")
        return 1

    subdomains_file = os.path.join(args.output_dir, f"{domain}.txt")
    live_file = os.path.join(args.output_dir, f"{domain}_live.txt")

    subfinder_bin = resolve_tool(args.subfinder_path, "subfinder", "SOURCE")
    if not subfinder_bin:
        log("ERROR: could not find a working 'subfinder' binary. "
            "Install it with: go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest")
        return 1
    log(f"Using subfinder at: {subfinder_bin}")

    httpx_bin = resolve_tool(args.httpx_path, "httpx", "-silent")
    if not httpx_bin:
        log("ERROR: could not find a working ProjectDiscovery 'httpx' binary "
            "(found something called httpx, but it didn't look like the right tool). "
            "Install it with: go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest")
        return 1
    log(f"Using httpx at: {httpx_bin}")

    if not run_subfinder(subfinder_bin, domain, subdomains_file, args.timeout):
        return 1

    total_found = count_lines(subdomains_file)
    log(f"subfinder found {total_found} subdomain(s). Saved to '{subdomains_file}'.")

    # Conditional: no point calling httpx on an empty list.
    if total_found == 0:
        log("No subdomains to probe -- skipping httpx step.")
        # Still create an empty live file so downstream tooling can rely on it existing.
        open(live_file, "a", encoding="utf-8").close()
    else:
        if not run_httpx(httpx_bin, subdomains_file, live_file, args.timeout):
            return 1

    total_live = count_lines(live_file)
    log(f"httpx confirmed {total_live} live host(s). Saved to '{live_file}'.")
    log("Done.")

    if args.discord_webhook:
        send_discord_notification(args.discord_webhook, domain, total_found, total_live)

    return 0


if __name__ == "__main__":
    sys.exit(main())
