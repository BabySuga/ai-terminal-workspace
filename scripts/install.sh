#!/usr/bin/env bash
# Installation script for AI Terminal Workspace (aiw)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "Installing AI Terminal Workspace (aiw)..."

# Ensure all scripts are executable
chmod +x "${PROJECT_ROOT}/bin/aiw"
chmod +x "${PROJECT_ROOT}/scripts/"*.sh

# Create local bin directory if needed and symlink aiw CLI
LOCAL_BIN="${HOME}/.local/bin"
mkdir -p "${LOCAL_BIN}"

ln -sf "${PROJECT_ROOT}/bin/aiw" "${LOCAL_BIN}/aiw"

echo "✓ Created executable symlink at ${LOCAL_BIN}/aiw"
echo "AI Terminal Workspace installation complete."
