# Clone repository
```
https://github.com/naguirre/calaos-os-2
```
# Build docker image

```
docker build --rm -t calaos-os-builder .
```

# Run docker container
```
docker run --rm -v `pwd`:/src -t -i --privileged calaos-os-builder
```

# Build iso
inside the container you can build the iso : 
```
cd /src
mkarchiso -v -w /tmp/calaos-os-tmp calaos-os
```

result is in out directory : 
