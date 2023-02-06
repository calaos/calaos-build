FROM debian:stable-slim

ARG UID=1001
ARG GID=1001
ARG USER=calaos

RUN apt -y update && \
    apt-get install -yq --no-install-recommends sudo mtools syslinux-utils parted

# Create user and its home
#RUN addgroup --gid ${GID} docker
RUN groupadd -g ${GID} docker
RUN useradd -d /home/${USER} -r -u ${UID} -g ${GID} ${USER}
RUN mkdir -p -m 0755 /home/${USER}
RUN chown ${USER} /home/${USER}
RUN echo 'calaos ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

USER ${USER}

# Define entry point
WORKDIR /src
