#!/usr/bin/env bash
# One-time setup: generate a CI-only keystore and register its bytes + passwords
# as GitHub Actions secrets on the current repo's `origin` fork.
#
# Prereqs:
#   - gh CLI installed and authenticated (`gh auth status` must succeed)
#   - keytool on PATH (any JDK installs it, e.g. java-17-openjdk-headless)
#   - origin pointed at your own fork (not eddyizm/tempus)
#
# The keystore itself is uploaded and then deleted locally — the only copy
# lives in GitHub secrets after this runs. If you ever need to rotate it,
# re-run this script; it overwrites the existing secrets.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

if ! command -v gh >/dev/null; then
    echo "ERROR: gh CLI not found. Install and run 'gh auth login' first." >&2
    exit 1
fi
if ! gh auth status >/dev/null 2>&1; then
    echo "ERROR: gh is not authenticated. Run 'gh auth login' first." >&2
    exit 1
fi
if ! command -v keytool >/dev/null; then
    echo "ERROR: keytool not found. Install a JDK (e.g. 'sudo dnf install -y java-17-openjdk-headless')." >&2
    exit 1
fi

ORIGIN_URL="$(git remote get-url origin)"
if [[ "$ORIGIN_URL" == *"eddyizm/tempus"* ]]; then
    echo "ERROR: origin still points at eddyizm/tempus. Rewire remotes first:" >&2
    echo "  git remote rename origin upstream" >&2
    echo "  git remote add origin https://github.com/<your-user>/tempus.git" >&2
    exit 1
fi
echo ">> Target repo: $ORIGIN_URL"

KEYSTORE_FILE="$(mktemp --suffix=.keystore)"
trap 'rm -f "$KEYSTORE_FILE"' EXIT

# Strip problem chars so passwords are safe to paste/echo everywhere
gen_pass() { openssl rand -base64 32 | tr -d '=+/\n' | cut -c1-32; }
KEYSTORE_PASSWORD="$(gen_pass)"
KEY_PASSWORD="$(gen_pass)"
KEY_ALIAS="ci"

echo ">> Generating keystore (RSA 2048, 30-year validity)"
keytool -genkeypair \
    -keystore "$KEYSTORE_FILE" \
    -alias "$KEY_ALIAS" \
    -keyalg RSA \
    -keysize 2048 \
    -validity 10950 \
    -storepass "$KEYSTORE_PASSWORD" \
    -keypass "$KEY_PASSWORD" \
    -dname "CN=Tempus CI, O=Tempus, C=US" \
    >/dev/null

echo ">> Uploading secrets"
base64 -w0 "$KEYSTORE_FILE" | gh secret set KEYSTORE_BASE64
printf "%s" "$KEYSTORE_PASSWORD" | gh secret set KEYSTORE_PASSWORD
printf "%s" "$KEY_PASSWORD"      | gh secret set KEY_PASSWORD
printf "%s" "$KEY_ALIAS"         | gh secret set KEY_ALIAS

echo ""
echo ">> Secrets registered on $ORIGIN_URL:"
gh secret list

cat <<'EOF'

Done. The keystore exists only as a GitHub secret now (local copy wiped).

One more manual step, if you haven't already: enable Actions on the fork.
  https://github.com/<your-user>/tempus/settings/actions
  → "Allow all actions and reusable workflows"

Then smoke-test:
  git push origin tesla-art-patch       # make sure the workflow file is on the branch
  gh workflow run sync-and-build.yml
  gh run watch

Notes
- `tesla-art-patch` is now effectively CI-owned: the workflow force-pushes
  rebased history to origin daily. Keep new local work on feature branches
  off tesla-art-patch, and push anything you do want preserved before the
  next CI run.
EOF
