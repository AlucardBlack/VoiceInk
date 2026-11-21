#!/bin/bash
# Update local VoiceInk to the newest upstream release tag and reinstall it.
# Usage: scripts/update.sh            (FORCE=1 rebuilds even if up to date,
#                                      REBUILD_WHISPER=1 rebuilds whisper.xcframework)
# Merges the newest tag into sergiy/tweaks, so your own commits stay on top.

main() {
  set -euo pipefail
  cd "$(dirname "$0")/.."

  [ "$(git branch --show-current)" = sergiy/tweaks ] || { echo "Switch to sergiy/tweaks first"; exit 1; }
  [ -z "$(git status --porcelain --untracked-files=no)" ] || { echo "Commit or stash your changes first"; exit 1; }

  git fetch upstream --tags --quiet
  git fetch upstream main:main --quiet 2>/dev/null || true   # keep main == upstream/main

  local tag old
  tag=$(git tag --list 'v[0-9]*' --sort=-v:refname | head -1)
  old=$(git rev-parse HEAD)

  if git merge-base --is-ancestor "$tag" HEAD && [ -d /Applications/VoiceInk.app ] && [ -z "${FORCE:-}" ]; then
    echo "Already on $tag and installed. FORCE=1 to rebuild."; exit 0
  fi

  echo "Updating to $tag"
  git merge --no-edit "$tag"

  # Upstream doesn't pin whisper.cpp; rebuild it when the build recipe changed.
  if [ -n "${REBUILD_WHISPER:-}" ] || ! git diff --quiet "$old" HEAD -- Makefile; then
    echo "Rebuilding whisper.xcframework"
    rm -rf "$HOME/VoiceInk-Dependencies/whisper.cpp/build-apple"
  fi

  make local

  osascript -e 'quit app "VoiceInk"' 2>/dev/null || true
  sleep 2
  rm -rf /Applications/VoiceInk.app
  ditto "$HOME/Downloads/VoiceInk.app" /Applications/VoiceInk.app
  rm -rf "$HOME/Downloads/VoiceInk.app"
  open /Applications/VoiceInk.app
  echo "Installed VoiceInk $tag in /Applications"
}

main "$@"   # whole file is read before git merge can rewrite it
