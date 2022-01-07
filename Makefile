

DOCKER_IMAGE_NAME = calaos-os-builder
DOCKER_TAG ?= latest
DOCKER_COMMAND = docker run -t -v $(PWD):/src --rm -w /src --privileged 

print_green = /bin/echo -e "\x1b[32m$1\x1b[0m"

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
	@ echo "  make build-iso                # Build Arch ISO"
	@ echo "  make build-|calaos-ddns|calaos-home|calaos-server|calaos-web-app|knxd|linuxconsoletools|ola|owfs|zigbee2mqtt # Build Arch package"
	@ echo "  make run                      # Run ISO through qemu, for testing purppose"
	@ echo

pkgbuilds-init:
	@scripts/get_pkgbuilds.sh

docker-init: Dockerfile
	docker build -t $(DOCKER_IMAGE_NAME):$(DOCKER_TAG) -f Dockerfile .

docker-shell: docker-init pkgbuilds-init
	@$(DOCKER_COMMAND) -it $(DOCKER_IMAGE_NAME):$(DOCKER_TAG) /bin/bash

docker-rm:
	@docker image rm $(DOCKER_IMAGE_NAME):$(DOCKER_TAG)

build-iso: docker-init pkgbuilds-init
	@$(DOCKER_COMMAND) $(DOCKER_IMAGE_NAME):$(DOCKER_TAG) sudo mkarchiso -v -w /tmp/calaos-os-tmp calaos-os

build-%: docker-init pkgbuilds-init
	@echo "Building $*"
	@$(DOCKER_COMMAND) $(DOCKER_IMAGE_NAME):$(DOCKER_TAG) /src/scripts/build_pkg.sh $*

run: build-iso
	qemu-system-x86_64 -boot d -cdrom out/*.iso -m 512
