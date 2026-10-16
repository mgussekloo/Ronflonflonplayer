# Paste into the Forge deployment script editor for STANDARD deployments.
# For zero-downtime deployments, use the macro-based script in deploy/README.md.
set -eu
cd "$FORGE_SITE_PATH"
git pull --ff-only origin "$FORGE_SITE_BRANCH"
sh tool/verify-release.sh
