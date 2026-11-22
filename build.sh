#!/bin/bash
# Cloudflare Pages build script for Flutter web
set -e

FLUTTER_HOME="$HOME/flutter"

if [ ! -d "$FLUTTER_HOME" ]; then
  git clone https://github.com/flutter/flutter.git -b stable --depth 1 "$FLUTTER_HOME"
fi

export PATH="$PATH:$FLUTTER_HOME/bin"

flutter config --enable-web
flutter pub get
flutter build web --release --base-href /
