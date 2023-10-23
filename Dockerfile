FROM debian:stable

ARG USER_UID=1001
ARG USER_GID=1001
ARG USER_NAME=build

RUN echo 'deb http://deb.debian.org/debian bullseye-backports main contrib non-free' >> /etc/apt/sources.list

RUN apt -y update && \
    apt -y upgrade && \
    apt-get install -yq --no-install-recommends ca-certificates wget gnupg \
        git fakeroot build-essential sudo nano mtools syslinux-common syslinux-efi parted \
        qemu-system-aarch64 qemu-system-x86 fdisk udev dosfstools qemu-efi qemu-efi-aarch64 ovmf \
        systemd-boot skopeo podman netavark jq

RUN groupadd -o -g ${USER_GID} -r docker
RUN useradd -d /home/${USER_NAME} -r -u ${USER_UID} -g ${USER_GID} ${USER_NAME}
RUN mkdir -p -m 0755 /home/${USER_NAME}
RUN chown ${USER_NAME} /home/${USER_NAME}

RUN echo "${USER_NAME} ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

USER ${USER_NAME}

# Define entry point
WORKDIR /src
