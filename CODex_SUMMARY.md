# CODex Summary

## Changed files

- `.github/workflows/build.yml`
  - Added `workflow_dispatch`.
  - Narrowed the workflow to the requested target only: FriendlyWrt `24.10`, `docker` set, `rk3588` image build.
  - Changed the final image artifact name to `NanoPi-R6S-FriendlyWrt-24.10-docker.img.gz`.

- `scripts/add_packages.sh`
  - Keeps the existing FriendlyWrt custom additions.
  - Vendors the native AmneziaWG packages from this repo into the upstream FriendlyWrt tree during CI.
  - Adds config fragments that explicitly select:
    - `docker`
    - `kmod-r8125`
    - `amneziawg-tools`
    - `kmod-amneziawg`
    - `luci-proto-amneziawg`
  - Reuses the upstream FriendlyWrt Docker config for:
    - `dockerd`
    - `docker-compose`
    - `luci-app-dockerman`
  - `kmod-wireguard` is already selected upstream in `configs/rockchip/01-nanopi`, so it was left in the existing mechanism.

- `scripts/custome_config.sh`
  - Keeps the existing SDK/toolchain cleanup.
  - Changes the rockchip default LAN IP source from `192.168.2.1` to `192.168.8.1`.
  - Updates the FriendlyWrt LuCI reconnect patch path so reset/reconnect logic matches `192.168.8.1`.

- `packages/amneziawg-openwrt/amneziawg-tools/*`
- `packages/amneziawg-openwrt/kmod-amneziawg/*`
- `packages/amneziawg-openwrt/luci-proto-amneziawg/*`
  - Vendored native AmneziaWG packages so the build does not depend on a live custom feed during GitHub Actions.

## AmneziaWG integration

- Source repo: `https://github.com/amnezia-vpn/amneziawg-openwrt`
- Vendored commit: `56bf9fed93df48d2b747edd6e7a7c5fbe2b01afe`
- Integration method: vendored package directories copied into `friendlywrt/package/amneziawg/` during CI.
- Included packages:
  - `amneziawg-tools`
  - `kmod-amneziawg`
  - `luci-proto-amneziawg`

## Pinned / patched items

- `packages/amneziawg-openwrt/kmod-amneziawg/Makefile`
  - `PKG_RELEASE` bumped to `2`.
  - `Build/Prepare` rewritten to use portable `cp` commands instead of shell brace expansion, which is brittle under `/bin/sh`.

- `packages/amneziawg-openwrt/kmod-amneziawg/files/000-initial-amneziawg.patch`
  - Rebased to apply cleanly against the current FriendlyWrt RK3588 kernel branch used by `master-v24.10`.
  - Dry-run checked against `friendlyarm/kernel-rockchip` branch `nanopi6-v6.1.y`, commit `c8ae7970abdc7d82af51f442ea29b307322a0199`.

## Docker note

- `luci-lib-docker` is not present as a standalone package in the current pinned LuCI feed used by FriendlyWrt `24.10`.
- Current `luci-app-dockerman` already pulls the active Docker UI stack for this branch, so the build keeps the current FriendlyWrt/OpenWrt 24.10 style instead of forcing an obsolete package.

## How to trigger the build

- In GitHub Actions, run the `build` workflow manually with `workflow_dispatch`.
- The old star-trigger still remains, but manual dispatch is now available and is the recommended path.

## What to download and flash

- Download the release asset:
  - `NanoPi-R6S-FriendlyWrt-24.10-docker.img.gz`
- Flash that `.img.gz` to an SD card.
- The workflow also uploads the intermediate rootfs bundle:
  - `rootfs-friendlywrt-24.10-docker.tgz`
  - That rootfs archive is not the file to flash.

## Release tag format

- The workflow creates a release tag in the form:
  - `FriendlyWrt-YYYY-MM-DD`
- For example, if you trigger it on March 31, 2026, the tag will be:
  - `FriendlyWrt-2026-03-31`
