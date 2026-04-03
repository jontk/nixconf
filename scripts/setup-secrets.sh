#!/usr/bin/env bash
# Setup secrets required for NixOS builds
# Run this on a fresh machine before the first nixos-rebuild
set -euo pipefail

SECRETS_DIR="/etc/nixos/secrets"

echo "=== NixConf Secrets Setup ==="
echo ""

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root (sudo)"
    exit 1
fi

# Create secrets directory
mkdir -p "$SECRETS_DIR"
chmod 700 "$SECRETS_DIR"

# User password hash
if [ ! -f "$SECRETS_DIR/jontk-password-hash" ]; then
    echo "Setting password for user 'jontk':"
    read -s -p "  Enter password: " PASSWORD
    echo ""
    read -s -p "  Confirm password: " PASSWORD_CONFIRM
    echo ""
    if [ "$PASSWORD" != "$PASSWORD_CONFIRM" ]; then
        echo "Passwords do not match"
        exit 1
    fi
    mkpasswd -m sha-512 "$PASSWORD" > "$SECRETS_DIR/jontk-password-hash"
    echo "  Created jontk-password-hash"
else
    echo "  jontk-password-hash already exists (skipping)"
fi

# Root password hash
if [ ! -f "$SECRETS_DIR/root-password-hash" ]; then
    echo ""
    echo "Root password:"
    read -p "  Use same password as jontk? [Y/n] " SAME
    if [ "${SAME:-Y}" = "n" ] || [ "${SAME:-Y}" = "N" ]; then
        read -s -p "  Enter root password: " ROOT_PASSWORD
        echo ""
        mkpasswd -m sha-512 "$ROOT_PASSWORD" > "$SECRETS_DIR/root-password-hash"
    else
        cp "$SECRETS_DIR/jontk-password-hash" "$SECRETS_DIR/root-password-hash"
    fi
    echo "  Created root-password-hash"
else
    echo "  root-password-hash already exists (skipping)"
fi

# Set permissions
chmod 600 "$SECRETS_DIR"/*
chown root:root "$SECRETS_DIR"/*

echo ""
echo "=== Secrets configured ==="
echo ""
ls -la "$SECRETS_DIR/"
echo ""
echo "You can now run: sudo nixos-rebuild switch --flake '.#nixos-dev'"
