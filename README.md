# Clone repository
```
https://github.com/calaos/calaos-build
```

# Help

```
Available commands :
====================

  make                          # Print this help
  make docker-init              # Build docker image, also build after any changes in Dockerfile
  make docker-shell             # Run docker container and jump into
  make docker-rm                # Remove a previous build docker image
  make calaos-os                # Build Calaos OS hddimg for installation
  make run                      # Run ISO through qemu, for testing purppose

Variables values :
=====================
example : make calaos-os NOCACHE=0

NOCACHE = 1            # Set to 0 if you want to accelerate Docker image build by using cache. default value NOCACHE=1.
```

# Make calaos-os hddimg
```
make calaos-os
```

result is in out directory 
