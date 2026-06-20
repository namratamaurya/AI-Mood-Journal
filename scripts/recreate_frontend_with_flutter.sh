#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FRONTEND_DIR="$ROOT_DIR/frontend"
BACKUP_DIR="$(mktemp -d)"

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter is not installed or not on PATH."
  echo "Install Flutter, then rerun: scripts/recreate_frontend_with_flutter.sh"
  exit 1
fi

echo "Checking Flutter installation..."
flutter doctor

echo "Backing up existing frontend source..."
cp -R "$FRONTEND_DIR/lib" "$BACKUP_DIR/lib"
cp "$FRONTEND_DIR/pubspec.yaml" "$BACKUP_DIR/pubspec.yaml"
cp "$FRONTEND_DIR/analysis_options.yaml" "$BACKUP_DIR/analysis_options.yaml"

echo "Recreating Flutter project structure..."
rm -rf "$FRONTEND_DIR"
flutter create --project-name ai_mood_journal --platforms web "$FRONTEND_DIR"

echo "Restoring app-specific frontend files..."
rm -rf "$FRONTEND_DIR/lib"
cp -R "$BACKUP_DIR/lib" "$FRONTEND_DIR/lib"
cp "$BACKUP_DIR/pubspec.yaml" "$FRONTEND_DIR/pubspec.yaml"
cp "$BACKUP_DIR/analysis_options.yaml" "$FRONTEND_DIR/analysis_options.yaml"

echo "Fetching Flutter dependencies..."
cd "$FRONTEND_DIR"
flutter pub get

echo "Frontend recreated successfully."
