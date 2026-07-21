#!/bin/bash
# security_scan.sh — run Gitleaks + Trivy via Docker, save raw output
#
# Usage:
#   ./security_scan.sh                    # scan current directory
#   ./security_scan.sh /path/to/project   # scan specified project
#
# Output (per tool, raw):
#   .scan-results/gitleaks.json
#   .scan-results/trivy.json
#
# Exit codes:
#   0 — clean (no findings above threshold)
#   1 — Gitleaks found secrets
#   2 — Trivy found HIGH/CRITICAL vulnerabilities
#   3 — both found issues

set -euo pipefail

PROJECT_ROOT="${1:-$PWD}"
cd "$PROJECT_ROOT"
mkdir -p .scan-results

TRIVY_CACHE_VOLUME="trivy-db-cache"
GITLEAKS_IMAGE="ghcr.io/gitleaks/gitleaks:latest"
TRIVY_IMAGE="aquasec/trivy:0.60.0"

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'
YELLOW='\033[1;33m'; BOLD='\033[1m'; NC='\033[0m'

echo -e "${BOLD}Security Scan — $PROJECT_ROOT${NC}"
echo "  $(date -u +%Y-%m-%dT%H:%M:%SZ)"

# ─── Gitleaks ──────────────────────────────────────────────────────────────

echo ""
echo -e "${BOLD}--- Gitleaks (secrets) ---${NC}"
GITLEAKS_EXIT=0

if docker info >/dev/null 2>&1; then
    set +e
    docker run --rm \
        -v "$PROJECT_ROOT:/repo" \
        "$GITLEAKS_IMAGE" \
        git --report-format json --report-path /repo/.scan-results/gitleaks.json /repo 2>&1
    GITLEAKS_EXIT=$?
    set -e

    if [ "$GITLEAKS_EXIT" -eq 0 ]; then
        echo -e "${GREEN}No secrets found${NC}"
    else
        COUNT=$(python3 -c "import json; print(len(json.load(open('.scan-results/gitleaks.json'))))" 2>/dev/null || echo "?")
        echo -e "${RED}Found $COUNT secret(s)${NC}"
    fi
else
    echo -e "${YELLOW}Docker not available — skipping Gitleaks${NC}"
fi

# ─── Trivy ─────────────────────────────────────────────────────────────────

echo ""
echo -e "${BOLD}--- Trivy (dependencies) ---${NC}"
TRIVY_EXIT=0

if docker info >/dev/null 2>&1; then
    set +e
    docker run --rm \
        -v "$PROJECT_ROOT:/work" \
        -w /work \
        -v "$TRIVY_CACHE_VOLUME:/root/.cache/" \
        "$TRIVY_IMAGE" \
        fs \
        --scanners vuln \
        --severity HIGH,CRITICAL \
        --exit-code 1 \
        --format json \
        --output /work/.scan-results/trivy.json \
        . 2>&1
    TRIVY_EXIT=$?
    set -e

    if [ "$TRIVY_EXIT" -eq 0 ]; then
        echo -e "${GREEN}No vulnerabilities above threshold${NC}"
    else
        echo -e "${RED}Vulnerabilities found — see .scan-results/trivy.json${NC}"
    fi
else
    echo -e "${YELLOW}Docker not available — skipping Trivy${NC}"
fi

# ─── Result ─────────────────────────────────────────────────────────────────

echo ""
FINAL_EXIT=0
[ "$GITLEAKS_EXIT" -ne 0 ] && FINAL_EXIT=$((FINAL_EXIT + 1))
[ "$TRIVY_EXIT" -ne 0 ] && FINAL_EXIT=$((FINAL_EXIT + 2))

if [ "$FINAL_EXIT" -eq 0 ]; then
    echo -e "${GREEN}Scan passed${NC}"
else
    echo -e "${RED}Scan found issues (exit $FINAL_EXIT)${NC}"
    echo "  .scan-results/gitleaks.json"
    echo "  .scan-results/trivy.json"
fi

exit "$FINAL_EXIT"
