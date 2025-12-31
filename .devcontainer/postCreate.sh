#!/usr/bin/env bash
set -euo pipefail

ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-/opt/android-sdk}"

sudo apt-get update
sudo apt-get install -y --no-install-recommends \
  ca-certificates \
  curl \
  unzip \
  git \
  bash \
  libc6 \
  libstdc++6 \
  zlib1g

# Ensure SDK directory exists and is writable for the current user
sudo mkdir -p "$ANDROID_SDK_ROOT"
sudo chown -R "$(id -u):$(id -g)" "$ANDROID_SDK_ROOT"

# Install Android commandline-tools (sdkmanager)
CMDLINE_TOOLS_DIR="$ANDROID_SDK_ROOT/cmdline-tools"
LATEST_DIR="$CMDLINE_TOOLS_DIR/latest"
if [[ ! -x "$LATEST_DIR/bin/sdkmanager" ]]; then
  tmpdir="$(mktemp -d)"
  curl -fsSL -o "$tmpdir/commandlinetools.zip" \
    "https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip"

  rm -rf "$LATEST_DIR"
  mkdir -p "$CMDLINE_TOOLS_DIR"
  unzip -q "$tmpdir/commandlinetools.zip" -d "$tmpdir"
  mkdir -p "$LATEST_DIR"
  mv "$tmpdir/cmdline-tools"/* "$LATEST_DIR/"
  rm -rf "$tmpdir"
fi

export PATH="$LATEST_DIR/bin:$ANDROID_SDK_ROOT/platform-tools:$PATH"

# Accept licenses and install required packages for this repo (compileSdk/targetSdk 35)
# Note: with `set -o pipefail`, `yes | ...` can exit 141 (SIGPIPE) when the consumer exits early.
# We temporarily disable pipefail so the pipeline exit status reflects `sdkmanager`, not `yes`.
set +o pipefail
yes | sdkmanager --sdk_root="$ANDROID_SDK_ROOT" --licenses >/dev/null
yes | sdkmanager --sdk_root="$ANDROID_SDK_ROOT" \
  "platform-tools" \
  "platforms;android-35" \
  "build-tools;35.0.0"
set -o pipefail

# Make SDK available in new shells
sudo tee /etc/profile.d/android-sdk.sh >/dev/null <<EOF
export ANDROID_SDK_ROOT="$ANDROID_SDK_ROOT"
export ANDROID_HOME="$ANDROID_SDK_ROOT"
export PATH="$LATEST_DIR/bin:$ANDROID_SDK_ROOT/platform-tools:\$PATH"
EOF

# Point Gradle/AGP to the SDK
if [[ -d "/workspaces" ]]; then
  repo_root="/workspaces/Seal-Desktop"
  if [[ -d "$repo_root" ]]; then
    printf 'sdk.dir=%s\n' "$ANDROID_SDK_ROOT" > "$repo_root/local.properties"
  fi
fi
