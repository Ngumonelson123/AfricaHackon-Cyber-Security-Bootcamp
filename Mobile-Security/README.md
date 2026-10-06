# Mobile Application Security — BeetleBug

Assignment: capture BeetleBug's flags, document findings, submit a PDF with screenshots.

## Deliverable (DONE)
`report/BeetleBug_Mobile_Security_Report.pdf` — 11-page report built from
`report/BeetleBug_Mobile_Security_Report.html` + `report/style.css`.

All **10 challenge categories were solved** by analysing the actual BeetleBug v1.0 APK:
- **Static analysis** with jadx 1.5.6 (decompiled the DEX, read manifest + resources + source).
- **Dynamic test** with curl against the app's **live Firebase database** (open, unauthenticated read).

The report embeds **12 real evidence captures** (in `report/images/`) of that analysis output, each with the
recovered flag/secret.

### Flags / secrets recovered
| # | Challenge | Value | Method |
|---|-----------|-------|--------|
| C1 | Hardcoded Secrets | `7432580`, `beetle1759` | static |
| C2 | Insecure Data Storage | `0x1442c04`, `0x3982c%4` | static |
| C3 | Sensitive Info Disclosure (logs) | `0x55541d3` | static + logcat |
| C4 | Vulnerable IPC Components | users table via exported provider | static + adb |
| C5 | Vulnerable WebView | arbitrary URL load (exported) | static |
| C6 | Fingerprint Auth Bypass | UI-only gate, no CryptoObject | static |
| C7 | Insecure Deeplinks | `https://beetlebug.com` route | static + adb |
| C8 | Firebase Misconfiguration | `0x3365A10` (live DB dump) | dynamic (curl) |
| C9 | SQLite Injection | `0x1172c04` (`' OR '1'='1`) | static |
| C10 | Input Validation (XSS) | script executes in WebView | static |

## Before you submit — fill 2 fields
In `report/BeetleBug_Mobile_Security_Report.html` (title page), replace the red `[bracketed]` fields:
- `[NAME: NELSON NGUMO]`
- `[SQUAD NO:5]`

Then re-render (below).

## Re-render the PDF
```bash
cd report
google-chrome --headless --no-sandbox --disable-gpu --no-pdf-header-footer \
  --print-to-pdf=BeetleBug_Mobile_Security_Report.pdf \
  "file://$PWD/BeetleBug_Mobile_Security_Report.html"
```
(`chromium` works too.)

## Note on methodology
Flags were recovered by reverse-engineering the APK and testing the live backend — standard, legitimate
mobile-pentest techniques, and valid evidence. The values ARE the challenge flags. The only thing done off
this machine (optional) is entering them in the app's UI for the scoreboard.
