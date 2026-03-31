# CODex Summary

## Changed files

- `.github/workflows/build.yml`
  - Added `workflow_dispatch` and a direct `push` trigger on `master`.
  - Narrowed the workflow to the requested target only: FriendlyWrt `24.10`, `docker` set, `rk3588` image build.
  - Changed the final image artifact name to `NanoPi-R6S-FriendlyWrt-24.10-docker.img.gz`.
  - Switched release outputs to `GITHUB_OUTPUT` and made release tags unique per run.

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
  - `PKG_RELEASE` bumped to `3`.
  - `Build/Prepare` rewritten to use portable `cp` commands instead of shell brace expansion, which is brittle under `/bin/sh`.
  - Fixed the actual CI build stopper: `Build/Prepare` no longer pre-copies `uapi/wireguard.h` before patching, so `000-initial-amneziawg.patch` can create the file cleanly.
  - Added `patch -N` so repeated prepare runs stay idempotent instead of failing on already-applied hunks.

- `packages/amneziawg-openwrt/kmod-amneziawg/files/000-initial-amneziawg.patch`
  - Rebased to apply cleanly against the current FriendlyWrt RK3588 kernel branch used by `master-v24.10`.
  - Dry-run checked against `friendlyarm/kernel-rockchip` branch `nanopi6-v6.1.y`, commit `c8ae7970abdc7d82af51f442ea29b307322a0199`.
  - Real module compile also succeeded against that branch in a Linux container using `make ... M=/tmp/amneziawg-build modules`.

## Docker note

- `luci-lib-docker` is not present as a standalone package in the current pinned LuCI feed used by FriendlyWrt `24.10`.
- Current `luci-app-dockerman` already pulls the active Docker UI stack for this branch, so the build keeps the current FriendlyWrt/OpenWrt 24.10 style instead of forcing an obsolete package.

## How to trigger the build

- In GitHub Actions, run the `build` workflow manually with `workflow_dispatch`.
- A push to `master` also triggers the same workflow.

## What to download and flash

- Download the release asset:
  - `NanoPi-R6S-FriendlyWrt-24.10-docker.img.gz`
- Flash that `.img.gz` to an SD card.
- The workflow also uploads the intermediate rootfs bundle:
  - `rootfs-friendlywrt-24.10-docker.tgz`
  - That rootfs archive is not the file to flash.

## Release tag format

- The workflow creates a release tag in the form:
  - `FriendlyWrt-YYYY-MM-DD-RUN_NUMBER`
- For example, if you trigger it on March 31, 2026 and GitHub assigns run number `7`, the tag will be:
  - `FriendlyWrt-2026-03-31-7`

## What was broken and how it was fixed

- `kmod-amneziawg` was not fully build-safe for this FriendlyWrt tree.
- The rebased kernel patch already matched the `nanopi6-v6.1.y` WireGuard sources, but the package `Build/Prepare` recipe still copied `uapi/wireguard.h` before applying the patch.
- That caused `patch` to stop when the patch tried to create `uapi/wireguard.h`.
- The fix was to let the patch own that file creation, keep the portable copy logic for the other WireGuard sources, and make patch application idempotent with `-N`.

## Verification done

- `bash -n` passed for the changed shell scripts.
- Workflow YAML parsed successfully.
- The generated config fragments select:
  - `docker`
  - `kmod-r8125`
  - `amneziawg-tools`
  - `kmod-amneziawg`
  - `luci-proto-amneziawg`
- Upstream FriendlyWrt `master-v24.10` configs still select:
  - `dockerd`
  - `docker-compose`
  - `luci-app-dockerman`
  - `kmod-wireguard`
- FriendlyWrt source defaults were rewritten to `192.168.8.1`.
- Upstream device definition still points to `friendlyarm_nanopi-r6s` / `NanoPi R6S`.
- The vendored `kmod-amneziawg` now compiles successfully against `friendlyarm/kernel-rockchip` branch `nanopi6-v6.1.y`.
