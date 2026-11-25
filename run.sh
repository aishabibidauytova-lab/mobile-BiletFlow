#!/usr/bin/env bash
# Runs the app on Windows when the project path has non-English letters, which
# the Android build tools cannot open. Maps the project to drive B: (this lasts
# until a restart) and starts `flutter run` from there.
# Usage, in Git Bash from the project folder:  ./run.sh
set -e

project="$(cd "$(dirname "$0")" && pwd)"

if [ ! -e /b/pubspec.yaml ]; then
  subst B: "$(cygpath -w "$project")"
fi

if ! cmp -s /b/pubspec.yaml "$project/pubspec.yaml"; then
  echo "Drive B: is used by something else. Free it with: subst B: /d" >&2
  exit 1
fi

cd /b
exec flutter run "$@"
