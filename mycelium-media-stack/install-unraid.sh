#!/usr/bin/env bash
# Wrapper — runs the full Unraid one-script setup (default IP 192.168.0.100)
exec bash "$(dirname "$0")/unraid/setup.sh" "$@"
