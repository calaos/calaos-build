

DOCKER_IMAGE_NAME = calaos-os-builder
DOCKER_TAG ?= latest
DOCKER_COMMAND = docker run -t -v $(PWD):/src --rm -w /src --privileged=true

REPO := calaos-dev
ARCH := x86_64
COMMIT :=
PKGVERSION :=

print_green = /bin/echo -e "\x1b[32m$1\x1b[0m"

NOCACHE?=1

ifeq ($(NOCACHE),1)
_NOCACHE=true
else
_NOCACHE=false
endif

all:
	$(info )
	@$(call print_green,"Available commands :")
	@$(call print_green,"====================")	
	@ echo
	@ echo "  make                          # Print this help"
	@ echo "  make pkgbuilds-init           # Clone/Update pkgbuilds repository"
	@ echo "  make docker-init              # Build docker image, also build after any changes in Dockerfile"
	@ echo "  make docker-shell             # Run docker container and jump into"
	@ echo "  make docker-rm                # Remove a previous build docker image"
	@ echo "  make calaos-os                # Build Calaos OS hddimg for installation"
	@ echo "  make build-|calaos-ddns|calaos-home|calaos-server|calaos-web-app|knxd|linuxconsoletools|ola|owfs # Build Arch package"
	@ echo "  make run                      # Run ISO through qemu, for testing purppose"
	@ echo
	@$(call print_green,"Variables values    :")
	@$(call print_green,"=====================")
	@$(call print_green,"example : make calaos-os NOCACHE=0")
	@ echo
	@ echo "NOCACHE = ${NOCACHE}            # Set to 0 if you want to accelerate Docker image build by using cache. default value NOCACHE=1. "
	@ echo

pkgbuilds-init: docker-init
	@$(call print_green,"Syncing pkgbuilds repo")
	@$(DOCKER_COMMAND) $(DOCKER_IMAGE_NAME):$(DOCKER_TAG) /src/scripts/get_pkgbuilds.sh

docker-init: Dockerfile
	@$(call print_green,"Building docker image")
	@docker build --no-cache=$(_NOCACHE) -t $(DOCKER_IMAGE_NAME):$(DOCKER_TAG) -f Dockerfile .

docker-shell: pkgbuilds-init
	@$(DOCKER_COMMAND) -it $(DOCKER_IMAGE_NAME):$(DOCKER_TAG) /bin/bash

docker-rm:
	@docker image rm $(DOCKER_IMAGE_NAME):$(DOCKER_TAG)

build-%: pkgbuilds-init
	@$(call print_green,"Building $* REPO=$(REPO) ARCH=$(ARCH)")
	@$(DOCKER_COMMAND) $(DOCKER_IMAGE_NAME):$(DOCKER_TAG) /src/scripts/build_pkg.sh "$*" "$(REPO)" "$(ARCH)" "$(COMMIT)" "$(PKGVERSION)"

docker-calaos-os-init: Dockerfile.calaos-os
	docker build --no-cache=$(_NOCACHE) -t calaos-os:latest -f Dockerfile.calaos-os .

calaos-os: docker-init docker-calaos-os-init
	@mkdir -p out
	@$(call print_green,"Export rootfs from docker")
	@docker export $(shell docker create calaos-os:latest) --output="out/calaos-os.rootfs.tar"
	@$(DOCKER_COMMAND) -it $(DOCKER_IMAGE_NAME):$(DOCKER_TAG) sudo /src/scripts/create_hddimg.sh

run-uefi:
	kvm -m 1024 -hda out/calaos-os.hddimg -hdb out/internal.hdd -net nic,model=virtio -net user -bios /usr/share/ovmf/OVMF.fd

run-bios:
	kvm -m 1024 -hda out/calaos-os.hddimg -hdb out/internal.hdd -net nic,model=virtio -net user
