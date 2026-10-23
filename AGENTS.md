# AGENTS.md

Build system of Calaos-OS (Debian bookworm based). Everything runs in Docker
containers driven by `Makefile`; the product is a bootable `.hddimg`.

## Commands

```
make                      # help (note: mentions `make run`, which does not exist)
make calaos-os            # full build: docker-init, docker-calaos-os-init, cache-images, rootfs export, image
make docker-init          # builder image only (Dockerfile)
make docker-shell         # shell in builder, repo on /src
make cache-images         # podman pull/save images listed in out/containers.list into out/containers
make delete-cache-images  # sudo rm -fr out/containers (inside the builder)
make run-amd64|run-bios   # qemu boot of out/calaos-os.hddimg (needs OVMF.fd in cwd for run-amd64)
make upload TARGET_ARCH=amd64 UPLOAD_KEY=...   # CI only
```

Variables: `TARGET_ARCH` (amd64/arm64, default host), `MACHINE` (`rpi64` forces
arm64 and uses `create_sdimg.sh`), `VERSION` (default `git describe`), `NOCACHE`
(default 0), `CONTAINER_ENGINE` (default docker).

## Layout

- `Makefile`: all orchestration.
- `Dockerfile`: builder image (user `build`, UID/GID = caller's, passwordless sudo).
- `Dockerfile.calaos-os`: arch-independent rootfs (Calaos APT repo via calaos-keyring, `calaos` meta-package, os-release, root password, initramfs grow hook).
- `Dockerfile.{amd64,arm64,rpi64}.calaos-os`: kernel/bootloader layer, selected by `MACHINE`/`TARGET_ARCH`.
- `scripts/create_hddimg.sh`: partitions a 4 GiB file with loop devices, extracts the rootfs tar, installs systemd-boot + syslinux, zstd-compresses. Runs as root in the builder.
- `scripts/export_image_names.sh`, `scripts/cache_images.sh`: container image cache (`/usr/share/calaos/*.source` -> `out/containers/*.tar`).
- `scripts/upload.sh`: PUT to the download server, channel by file name (`rc`/`alpha`/`-dev` -> experimental, else stable).
- `calaos-os/`: boot menu config and splash, initramfs resize hooks, networkd config.
- `scripts/create_sdimg.sh`, `launch_rpi.sh`, `launch_arm64.sh`, `pre_arm64_launch.sh`, `quirks/`, `Dockerfile.rpi64.calaos-os`: Raspberry Pi / arm64 paths, apparently stale.
- Dead or unused: `scripts/calaos_lib.sh` pacman/upload helpers, `calaos-os/initramfs/mkinitcpio.conf` (Arch leftovers), `releases.calaos.json` (read by nothing), `REPO`/`COMMIT`/`PKGVERSION` in the Makefile.
- `out/` and `pkgbuilds` are git-ignored; `out/` holds all build products.

The Calaos services, container definitions and the installer are delivered by
Debian packages (`calaos`, `calaos-keyring` from github.com/calaos/pkgdebs),
not by this repo. Nothing here configures btrfs, snapper or calaos-container;
the image rootfs created here is ext4.

## Verifying a change

- There are no tests or linters. Static checks you can run cheaply:
  `bash -n scripts/*.sh`, `make -n calaos-os`, `docker build` of a single
  Dockerfile.
- A real verification is a full `make calaos-os` (see CI: ubuntu-latest, amd64
  only). It downloads Debian packages and container images, needs a privileged
  container with loop devices, and writes a 4 GiB image plus a ~2 GiB `.zst`
  and a ~1 GiB rootfs tar. Expect a long, network- and disk-heavy run (tens of
  GiB of disk with Docker layers and the image cache). Do not start it without
  being asked.
- Boot test: `make run-bios` (or `run-amd64` with `OVMF.fd`).

## Gotchas

- Do not build in a shared checkout: `out/` may already hold multi-GiB
  artifacts, and the image step rewrites `out/` (`rootfs_mount`, `boot`,
  the image files, the `calaos-os.hddimg` symlink).
- Outputs written by `create_hddimg.sh` are owned by root (run via sudo).
  Removing them (`out/`, `rootfs_mount`) needs sudo; use `make delete-cache-images`
  for `out/containers`. Docker also leaves root-owned files in worktrees.
- `cache-images` bind-mounts the host `/var/lib/containers` and runs
  `sudo podman pull` there, so it modifies the host's root podman storage.
- The `create_hddimg.sh` script creates `/dev/loopN` nodes and attaches loop
  devices; a failed run can leave loop devices attached and mounts under
  `out/rootfs_mount`. Check `losetup -a` and `mount` before retrying.
- `out/containers/<name>.tar` is reused if present, even if the upstream image
  changed. Use `make delete-cache-images` to refresh.
- The `docker build` of the `calaos-os:latest` tag happens twice (base, then
  arch layer); both use the same tag, so concurrent builds on one engine
  collide.
- Package installs are unpinned: builds are not reproducible.
- `rpi64` and `arm64` paths are untested here; `create_sdimg.sh` greps for a
  file name that does not match its output name.
- Default root password is `calaos` with SSH root login (intentional for the
  live/install image).

## Workflow

- A push to `main` triggers `.github/workflows/build.yml`: it bumps the
  version (prerelease), builds the amd64 image, creates a GitHub release/tag
  flagged prerelease, and uploads the `.hddimg.zst` to the `experimental`
  channel of the download server. Pushing therefore publishes an image and
  consumes CI minutes: never push without explicit approval.
- `workflow_dispatch` with `vincrement` major/minor/patch makes a
  non-prerelease release uploaded to `stable`.
- The workflow only runs on `main`; no PR build or check exists.
- Keep comments in scripts and Dockerfiles short and about the why.
