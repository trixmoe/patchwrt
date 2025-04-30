FROM debian:12

# Installing packages: (1) tools (2) OpenWRT deps (3) hidden OpenWRT deps
RUN apt-get update && \
    apt-get upgrade -y && \
    apt install -y vim tmux ccache \
                build-essential asciidoc bash binutils bzip2 flex git g++ gcc time util-linux gawk gzip help2man intltool libelf-dev zlib1g-dev make libncurses-dev libssl-dev patch perl-modules libthread-queue-any-perl python3-dev swig unzip wget gettext xsltproc zlib1g-dev \
                rsync

# OpenWRT buildsystem requires non-root user
RUN useradd -ms /bin/bash user
ENV BUILD_DIR=/vps/build/
WORKDIR $BUILD_DIR
RUN chown -R user /vps/
USER user

# Minimal copy to allow for maximum caching
COPY --chown=user modules ./
COPY --chown=user scripts ./scripts
RUN ./scripts/update.sh
# Copy everything else that's important and might change more often
COPY --chown=user Makefile ./
COPY --chown=user patches ./patches
COPY --chown=user .git/ ./.git/
COPY --chown=user .gitignore ./