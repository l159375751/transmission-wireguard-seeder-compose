# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository contains a Podman setup for running Transmission BitTorrent client with WireGuard VPN integration using wg-netns (network namespaces) for secure torrenting/seeding.

## Architecture

- **wg-netns**: Python script that creates Linux network namespaces with WireGuard VPN
- **Podman**: Container runtime that natively supports attaching to network namespaces
- **Transmission**: BitTorrent client running in a container attached to the VPN namespace

All Transmission traffic is routed through the WireGuard VPN with kernel-level isolation.

## Key Technologies

- [wg-netns](https://github.com/dadevel/wg-netns) - WireGuard with Linux network namespaces
- [Podman](https://podman.io/) - Daemonless container engine
- [Transmission](https://transmissionbt.com/) - BitTorrent client
- WireGuard - Modern VPN protocol

## Note

This project uses **Podman only** (not Docker) due to Podman's native support for Linux network namespaces via `--network ns:/run/netns/<name>`.
