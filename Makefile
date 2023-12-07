REPO := calaos-dev
COMMIT :=
PKGVERSION :=
CONTAINER_ENGINE ?= docker
DOCKER_IMAGE_NAME = calaos-os-builder
DOCKER_TAG ?= latest
DOCKER_COMMAND = $(CONTAINER_ENGINE) run --platform linux/${BUILDARCH} -t -v $(PWD):/src --rm -w /src --privileged=true
VERSION?=$(shell git describe --long --tags --always)

print_green = @echo "\033[92m$1\033[0m"

NOCACHE?=0

# Detect build architecture
BUILDARCH ?= $(shell uname -m)
ifeq ($(BUILDARCH),aarch64)
    BUILDARCH=arm64
endif
ifeq ($(BUILDARCH),x86_64)
    BUILDARCH=amd64
endif

# By default target architecture is same as build architecture, i.e no cross compiling
TARGET_ARCH ?= $(BUILDARCH)

# Override Target arch if rpi64 machine is specified
MACHINE ?= $(TARGET_ARCH)
ifeq ($(MACHINE),rpi64)
    override TARGET_ARCH=arm64
endif


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
	@ echo "  make docker-init              # Build docker image, also build after any changes in Dockerfile"
	@ echo "  make docker-shell             # Run docker container and jump into"
	@ echo "  make docker-rm                # Remove a previous build docker image"
	@ echo "  make calaos-os                # Build Calaos OS hddimg for installation"
	@ echo "  make run                      # Run ISO through qemu, for testing purppose"
	@ echo
	@ echo "  make cache-images             # Export all containers images to cache"
	@ echo "  make delete-cache-images      # Remove all cached images"
	@ echo
	@$(call print_green,"Variables values    :")
	@$(call print_green,"=====================")
	@$(call print_green,"example : make calaos-os NOCACHE=0")
	@ echo
	@ echo "NOCACHE = ${NOCACHE}            # Set to 0 if you want to accelerate Docker image build by using cache. default value NOCACHE=1. "
	@ echo

docker-init: Dockerfile
	@$(call print_green,"Building docker image")
	@$(CONTAINER_ENGINE) build --platform linux/${BUILDARCH} --no-cache=$(_NOCACHE) -t $(DOCKER_IMAGE_NAME):$(DOCKER_TAG) \
		--build-arg="USER_UID=$(shell id -u)" \
        --build-arg="USER_GID=$(shell id -g)" \
		-f Dockerfile .

docker-shell:
	@$(DOCKER_COMMAND) -it $(DOCKER_IMAGE_NAME):$(DOCKER_TAG) /bin/bash

docker-rm:
	@$(CONTAINER_ENGINE) image rm $(DOCKER_IMAGE_NAME):$(DOCKER_TAG)

docker-calaos-os-init: Dockerfile.$(TARGET_ARCH).calaos-os
	$(CONTAINER_ENGINE) build --platform linux/$(TARGET_ARCH) --no-cache=$(_NOCACHE) --build-arg "VERSION=$(VERSION)" -t calaos-os:latest -f Dockerfile.calaos-os .
	$(CONTAINER_ENGINE) build --platform linux/$(TARGET_ARCH) --no-cache=$(_NOCACHE) -t calaos-os:latest -f Dockerfile.$(MACHINE).calaos-os .
	@mkdir -p out/containers.list
	$(DOCKER_COMMAND) calaos-os:latest /src/scripts/export_image_names.sh

cache-images:
	$(DOCKER_COMMAND) \
		-v /var/lib/containers:/var/lib/containers \
		$(DOCKER_IMAGE_NAME):$(DOCKER_TAG) \
		/src/scripts/cache_images.sh

delete-cache-images:
	@$(DOCKER_COMMAND) \
		-v /var/lib/containers:/var/lib/containers \
		$(DOCKER_IMAGE_NAME):$(DOCKER_TAG) \
		sudo rm -fr /src/out/containers

calaos-os: docker-init docker-calaos-os-init cache-images
	@mkdir -p out
	@$(call print_green,"Export rootfs from docker")
	@$(CONTAINER_ENGINE) export $(shell $(CONTAINER_ENGINE) create --platform linux/$(TARGET_ARCH) calaos-os:latest) --output="out/calaos-os.rootfs.tar"
ifeq ($(MACHINE), rpi64)
	$(DOCKER_COMMAND) $(DOCKER_IMAGE_NAME):$(DOCKER_TAG) sudo /src/scripts/create_sdimg.sh "${VERSION}"
else
	$(DOCKER_COMMAND) $(DOCKER_IMAGE_NAME):$(DOCKER_TAG) sudo /src/scripts/create_hddimg.sh "${VERSION}"
endif

run-amd64: out/internal.hdd
	qemu-system-x86_64 -m 1024 \
	 	-drive file=out/calaos-os.hddimg,format=raw \
		-drive file=out/internal.hdd,format=raw \
		-bios OVMF.fd\
		-nic user,hostfwd=tcp::2222-:22

run-bios: out/internal.hdd
	qemu-system-x86_64  -m 1024 \
		-drive file=out/calaos-os.hddimg,format=raw \
		-drive file=out/internal.hdd,format=raw \
		-net nic,model=virtio -net user -nic user,hostfwd=tcp::2222-:22

run-arm64:
	@$(DOCKER_COMMAND) $(DOCKER_IMAGE_NAME):$(DOCKER_TAG) scripts/pre_arm64_launch.sh
	scripts/launch_arm64.sh

run-rpi64:
	@$(DOCKER_COMMAND) $(DOCKER_IMAGE_NAME):$(DOCKER_TAG) \
		sudo /src/scripts/launch_rpi.sh

out/internal.hdd:
	@truncate -s 10G out/internal.hdd