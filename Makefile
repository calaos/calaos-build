

DOCKER_IMAGE_NAME=calaos-os-builder
DOCKER_TAG ?= latest
DOCKER_COMMAND = docker run -t -v $(PWD):/src --rm -w /src --privileged 

docker-init: Dockerfile
	docker build -t $(DOCKER_IMAGE_NAME):$(DOCKER_TAG) -f Dockerfile .

docker-shell: docker-init
	@$(DOCKER_COMMAND) -it $(DOCKER_IMAGE_NAME):$(DOCKER_TAG) /bin/bash

docker-rm:
	@docker image rm $(DOCKER_IMAGE_NAME):$(DOCKER_TAG)

build-iso: docker-init
	@$(DOCKER_COMMAND) $(DOCKER_IMAGE_NAME):$(DOCKER_TAG) sudo mkarchiso -v -w /tmp/calaos-os-tmp calaos-os

build-%:
	@echo "Building $*"
	@$(DOCKER_COMMAND)  -w /src/pkgbuilds/$* $(DOCKER_IMAGE_NAME):$(DOCKER_TAG) makepkg -s --noconfirm


run: build-iso
	qemu-system-x86_64 -boot d -cdrom out/*.iso -m 512
