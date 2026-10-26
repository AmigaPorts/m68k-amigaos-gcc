FROM amigadev/docker-base:latest
WORKDIR /root/amiga-gcc
COPY ./ ./
ARG PATHPREFIX="m68k-amigaos"
ARG BINUTILS_BRANCH="amiga-2.46"
ARG GCC_BRANCH="amiga16.2"
# a release tag such as v16.2-rc21: every module is built at the tag release-tag made in it, and the branches are ignored
ARG RELEASE_TAG=""

RUN export DEBIAN_FRONTEND=noninteractive && \
    export HOST_ARCH=$(gcc -dumpmachine 2>/dev/null || dpkg-architecture -qDEB_HOST_GNU_TYPE) && \
    export PREFIX=/opt/${PATHPREFIX} && \
    command -v lha && \
    echo "HOST_ARCH:       ${HOST_ARCH}" && \
    echo "PREFIX:          ${PREFIX}" && \
    echo "BINUTILS_BRANCH: ${BINUTILS_BRANCH}" && \
    echo "GCC_BRANCH:      ${GCC_BRANCH}" && \
    echo "RELEASE_TAG:     ${RELEASE_TAG}" && \
    if [ -n "${RELEASE_TAG}" ]; then \
        make v ref=m68k-amigaos-gcc-${RELEASE_TAG}; \
    else \
        make branch mod=binutils branch=${BINUTILS_BRANCH} && \
        make branch mod=gcc branch=${GCC_BRANCH}; \
    fi && \
    make update && \
    make -j $(nproc) all && \
    make -j 4 all-sdk && \
    make -j $(nproc) zlib libpng && \
    cd / && \
    rm -rf /root/amiga-gcc && \
    apt-get purge -y \
    bison \
    flex \
    g++ \
    gcc \
    gettext \
    git \
    libncurses-dev \
    rsync \
    texinfo \
    wget \
    && apt-get -y autoremove

ENV PATH=/opt/${PATHPREFIX}/bin:$PATH
