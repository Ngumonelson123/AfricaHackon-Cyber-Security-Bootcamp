#!/usr/bin/env bash
# Deploy & run ScoutSuite against the Azure lab.
# Works in Azure Cloud Shell (bash) or any Linux box with az CLI + Python 3.9–3.11.
set -euo pipefail

REPORT_DIR="${REPORT_DIR:-$HOME/scoutsuite-report}"
VENV="${VENV:-$HOME/scoutsuite-venv}"

# 1. Authenticate (Cloud Shell is already logged in)
az account show >/dev/null 2>&1 || az login
SUB_ID="$(az account show --query id -o tsv)"
TENANT_ID="$(az account show --query tenantId -o tsv)"
echo "[*] Subscription: $SUB_ID  Tenant: $TENANT_ID"

# 2. Install ScoutSuite in an isolated virtualenv
if [ ! -x "$VENV/bin/scout" ]; then
  python3 -m venv "$VENV"
  "$VENV/bin/pip" install --upgrade pip
  "$VENV/bin/pip" install scoutsuite
fi

# 3. Run the Azure scan with the CLI identity.
#    The signed-in account needs: Reader + Security Reader on the subscription,
#    and Directory read (Global Reader) in Entra ID for the AAD/RBAC checks.
"$VENV/bin/scout" azure --cli \
  --subscriptions "$SUB_ID" \
  --tenant "$TENANT_ID" \
  --report-dir "$REPORT_DIR" \
  --no-browser

echo "[+] Report: $REPORT_DIR/scoutsuite-report/ (open the .html file)"
echo "[+] Summarise findings: python3 $(dirname "$0")/extract_findings.py $REPORT_DIR"

# --- Fallback if pip install fails on your Python version: Docker ---------
# docker run --rm -it -v "$HOME/.azure:/root/.azure" -v "$REPORT_DIR:/report" \
#   rossja/ncc-scoutsuite:azure-latest \
#   scout azure --cli --report-dir /report --no-browser
