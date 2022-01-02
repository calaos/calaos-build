

DOCKER_IMAGE_NAME=calaos-os-builder
DOCKER_TAG ?= latest
DOCKER_COMMAND = docker run -t -v $(PWD):/src --rm -it -w /src --privileged $(DOCKER_IMAGE_NAME):$(DOCKER_TAG)

docker-init: Dockerfile
	docker build -t $(DOCKER_IMAGE_NAME):$(DOCKER_TAG) -f Dockerfile .

docker-shell: docker-init
	@$(DOCKER_COMMAND) /bin/bash

docker-rm:
	@docker image rm $(DOCKER_IMAGE_NAME):$(DOCKER_TAG)

build-iso: docker-init
	@$(DOCKER_COMMAND) mkarchiso -v -w /tmp/calaos-os-tmp calaos-os
