#!/usr/bin/env bash
# deploy.sh — build and deploy to GitHub Pages
# Usage: bash deploy.sh
set -e

REPO="sramaka/amarakosha"
REPO_NAME="amarakosha"
BASE_HREF="/${REPO_NAME}/"
REMOTE="https://github.com/${REPO}.git"

echo ""
echo "==> Building Flutter web (base-href: ${BASE_HREF}) ..."
flutter build web --release --base-href "$BASE_HREF"

echo ""
echo "==> Deploying build/web to gh-pages branch ..."

cd build/web
git init -q
git checkout -b gh-pages
git add -A
git commit -q -m "Deploy $(date +'%Y-%m-%d %H:%M')"
git push -f "$REMOTE" HEAD:gh-pages
cd ../..

rm -rf build/web/.git

echo ""
echo "Done. Live at: https://sramaka.github.io/amarakosha/"
