# calaos-build

Build system for Calaos-OS, the Debian-based Linux distribution that runs the
[Calaos](https://calaos.fr) home automation suite. It produces a bootable
disk image (`.hddimg`) used to install Calaos-OS, plus the intermediate rootfs
tarball.

The whole build runs inside containers (Docker by default); nothing but
`make`, `git` and a container engine is needed on the host.

## What it builds

| Target machine      | Command                              | Output                                   | Status |
|---------------------|--------------------------------------|------------------------------------------|--------|
| amd64 (x86_64 PC)   | `make calaos-os TARGET_ARCH=amd64`   | `out/calaos-os-amd64-v<version>.hddimg` (+ `.zst`) | Built by CI |
| arm64 (generic)     | `make calaos-os TARGET_ARCH=arm64`   | `out/calaos-os-arm64-v<version>.hddimg`  | Dockerfile exists, disabled in CI, not verified here |
| Raspberry Pi 64-bit | `make calaos-os MACHINE=rpi64`       | `out/calaos-os-arm64-<version>.sdimg`    | Legacy, see "Known limitations" |

`TARGET_ARCH` defaults to the build host architecture (`uname -m`, mapped to
`amd64`/`arm64`), so a plain `make calaos-os` builds for the host.

Other outputs in `out/`:

- `calaos-os.rootfs.tar`: exported rootfs of the Calaos-OS container image
- `calaos-os.hddimg`: symlink to the latest `.hddimg`
- `containers/*.tar`: OCI archives of the container images preloaded in the image
- `containers.list/*.source`: image sources read from the installed packages
- `boot/`, `rootfs_mount/`: scratch directories left by the image script

## Build host requirements

- Linux with `make`, `git`, and Docker (or another engine passed through
  `CONTAINER_ENGINE=`; only Docker is exercised by CI).
- Privileges: the image step runs a `--privileged` container that creates loop
  devices, mounts filesystems and calls `sudo`. The container image gives the
  `build` user passwordless sudo.
- `/var/lib/containers` of the host is bind-mounted into the builder so that
  `podman pull` of the application images is done as root and cached there
  (see "Container images").
- Network access: Debian mirrors, `github.com` (calaos-keyring), the Calaos
  APT repository, `starship.rs`, and the container registries.
- Disk: the image is a 4 GiB sparse file, compressed with `zstd -19`. A
  previous build in the reference checkout produced a 4 GiB `.hddimg`, a
  2.2 GiB `.zst` and a 1.1 GiB rootfs tarball, plus the container image
  cache and Docker layers. Plan for tens of GiB free.
- Cross-building (e.g. arm64 on amd64) goes through `docker --platform` and
  therefore needs qemu user-mode emulation (binfmt) configured on the host.
  This is not exercised by CI.

## How to build

```
git clone https://github.com/calaos/calaos-build
cd calaos-build
make calaos-os
```

`make calaos-os` runs, in order:

1. `docker-init`: builds the `calaos-os-builder` image from `Dockerfile`
   (Debian bookworm with parted, mtools, syslinux, systemd-boot, qemu, ovmf,
   podman, skopeo, zstd...). The `build` user gets your UID/GID so files
   created without sudo are owned by you.
2. `docker-calaos-os-init`: builds the `calaos-os:latest` image from
   `Dockerfile.calaos-os`, then layers `Dockerfile.<MACHINE>.calaos-os` on top
   (kernel and architecture-specific packages), and copies the
   `/usr/share/calaos/*.source` files out of it into `out/containers.list/`.
3. `cache-images`: pulls and saves every container image listed there into
   `out/containers/` (skipped per image if the tarball already exists).
4. Exports the rootfs to `out/calaos-os.rootfs.tar` and runs
   `scripts/create_hddimg.sh` (or `create_sdimg.sh` for `rpi64`) as root in the
   builder container.

Useful targets and variables (`make` with no argument prints the help):

| Item | Meaning |
|------|---------|
| `make docker-init` | Build only the builder image |
| `make docker-shell` | Interactive shell in the builder, repo mounted on `/src` |
| `make docker-rm` | Remove the builder image |
| `make cache-images` / `make delete-cache-images` | Fill / delete `out/containers` |
| `VERSION=` | Version string embedded in `/usr/lib/os-release` and file names. Default: `git describe --long --tags --always` |
| `TARGET_ARCH=`, `MACHINE=` | Target architecture (`amd64`, `arm64`) / machine (`rpi64` forces `arm64`) |
| `NOCACHE=` | `1` passes `--no-cache` to the image builds. The Makefile default is `0` (the help text says `1`, it is wrong) |
| `CONTAINER_ENGINE=` | Defaults to `docker` |

The build is not incremental in the usual sense: `calaos-os` always rebuilds
the images and the disk image (Docker layer caching still applies unless
`NOCACHE=1`). The `apt` layers are not pinned, so a rebuild picks up whatever
the mirrors and the Calaos repository currently serve.

### Dev vs release channel

The channel is decided by the version string and by the CI, not by a Makefile
option:

- A push to `main` builds with a bumped prerelease version and uploads the
  image to the `experimental` channel. A GitHub release is created and flagged
  as prerelease.
- A manual run of the workflow with `vincrement` = `major`, `minor` or `patch`
  produces a non-prerelease version.
- `scripts/upload.sh` routes a file whose name contains `rc`, `alpha` or
  `-dev` to `experimental`, anything else to `stable`.

Which APT channel of the Calaos packages ends up in the image is defined by
the `calaos-keyring` / `calaos` packages (repo `calaos/pkgdebs`), not by this
repository.

## What the image contains

The rootfs is a Debian 12 (bookworm) system built in `Dockerfile.calaos-os`:

- systemd, systemd-networkd (DHCP on `en*` interfaces, `calaos-os/services/config.network`),
  systemd-resolved, systemd-timesyncd, OpenSSH server, `fuse-overlayfs`,
  GRUB EFI packages, standard network and admin tools, `starship` prompt.
- Non-free firmware components of Debian enabled; on amd64 `linux-image-amd64`,
  `firmware-linux`, syslinux and extlinux.
- The Calaos APT repository, configured by installing the `calaos-keyring`
  package (downloaded from the `calaos/pkgdebs` GitHub releases), then the
  `calaos` meta-package. That package is what brings in the Calaos services
  and the container definitions (see below).
- `root` account with the default password `calaos` and SSH root login enabled.
  Change both on any machine that is not a throwaway test box.
- A custom `os-release` ("Calaos OS", version from `VERSION`), a reset
  `machine-id`, and a first-boot rootfs growth hook in the initramfs
  (`calaos-os/initramfs`).

The Calaos application stack (calaos_server, Calaos Home, the system
container daemon, the btrfs/snapper layout that the installed system uses,
etc.) is delivered by the `calaos` packages and is not defined in this
repository. Inspect the `calaos` Debian package to see it.

## Boot and install

`scripts/create_hddimg.sh` builds a 4 GiB MBR disk image with:

- partition 1: a ~99 MiB FAT32 ESP with systemd-boot (`EFI/`, `loader/`),
  the kernel and initramfs copied to it;
- partition 2: ext4 rootfs holding the extracted rootfs tar and the container
  cache in `/var/lib/cache/containers`;
- a syslinux MBR and `boot/syslinux/syslinux.cfg` for legacy BIOS boot;
- a `/.calaos-live` marker file.

UEFI boot offers two systemd-boot entries, BIOS boot offers the equivalent
syslinux menu:

- "Boot USB Calaos v4 Live": boots the image as a live system;
- "Install Calaos OS to disk": same, with the `calaos_install` kernel
  parameter. The installer itself is shipped by the Calaos packages, not by
  this repository.

Write the image to a USB stick, for example:

```
zstd -d out/calaos-os-amd64-v<version>.hddimg.zst
sudo dd if=out/calaos-os-amd64-v<version>.hddimg of=/dev/sdX bs=4M conv=fsync status=progress
```

### Test in QEMU

Needs `qemu-system-x86_64` on the host; the UEFI variant also needs `OVMF.fd`
in the current directory.

```
make run-amd64    # UEFI, ssh forwarded on localhost:2222
make run-bios     # legacy BIOS, ssh forwarded on localhost:2222
```

Both attach a 10 GiB empty `out/internal.hdd` as the install target.
(There is no plain `make run` target although the help mentions it.)

## Packages and container images

- Debian packages: installed with `apt` in `Dockerfile.calaos-os` and the
  per-machine Dockerfile. The Calaos packages come from the Calaos APT
  repository.
- Container images: each Calaos package ships `/usr/share/calaos/<name>.source`
  files defining `IMAGE_SRC`. `scripts/export_image_names.sh` copies them out of
  the built image, `scripts/cache_images.sh` runs `podman pull` + `podman save
  --format oci-archive` for each into `out/containers/<name>.tar`, and the
  image script copies that directory to `/var/lib/cache/containers` on the
  image so that the first start does not need the network.
- `releases.calaos.json` lists container image names, sources and versions
  (calaos_base, calaos_home, haproxy, zigbee2mqtt, mosquitto, influxdb,
  grafana). Nothing in this repository reads it.

## CI and release

`.github/workflows/build.yml` ("Build Calaos-OS") runs on every push to `main`
and on manual dispatch. It bumps the version with `calaos/action-bump-version`,
runs `make calaos-os TARGET_ARCH=amd64 VERSION=<bumped>`, creates a GitHub
release/tag with that version, then runs `make upload`, which pushes the
`.hddimg.zst` to the Calaos download server (needs the `UPLOAD_KEY` secret).
The arm64 matrix entry is commented out.

## Known limitations

- `rpi64` / `create_sdimg.sh` looks stale: it greps `calaos-os.sdimg1` in
  `fdisk` output while the file is named `calaos-os-<arch>-<version>.sdimg`,
  and `Dockerfile.rpi64.calaos-os` uses the Raspberry Pi bullseye repository.
  Untested.
- `scripts/create_hddimg.sh` installs the x86 syslinux MBR regardless of
  architecture, so `arm64` `.hddimg` images are UEFI-only at best.
- `scripts/calaos_lib.sh` (pacman, Arch package upload) and
  `calaos-os/initramfs/mkinitcpio.conf` are leftovers from an Arch-based
  predecessor; only the logging helpers and variables of the former are used.

## License

No license file is present in this repository. Check the
[Calaos organization](https://github.com/calaos) for the project license.
