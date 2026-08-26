FROM amigadev/docker-base:latest
WORKDIR /root
COPY ./ ./
ARG PATHPREFIX="m68k-amigaos"
ARG BINUTILS_BRANCH="amiga-2.46"
ARG GCC_BRANCH="amiga6"
ENV NDK="3.9"

RUN export DEBIAN_FRONTEND=noninteractive && \
    export HOST_ARCH=$(gcc -dumpmachine 2>/dev/null || dpkg-architecture -qDEB_HOST_GNU_TYPE) && \
    export PREFIX=/opt/${PATHPREFIX} && \
    apt update && \
    apt install -y gcc-15 g++-15 && \
    rm -rf /var/lib/apt/lists/* && \
    command -v lha && \
    echo "HOST_ARCH:       ${HOST_ARCH}" && \
    echo "PREFIX:          ${PREFIX}" && \
    echo "BINUTILS_BRANCH: ${BINUTILS_BRANCH}" && \
    echo "GCC_BRANCH:      ${GCC_BRANCH}" && \
    make branch mod=binutils branch=${BINUTILS_BRANCH} && \
    make branch mod=gcc branch=${GCC_BRANCH} && \
    make update && \
    make -j $(nproc) GDB_CC=gcc-15 GDB_CXX=g++-15 all && \
    make -j $(nproc) sdk sdk=filesysbox && \
    make -j $(nproc) sdk sdk=sdi && \
    make -j $(nproc) sdk sdk=ahi && \
    make -j $(nproc) sdk sdk=mhi && \
    make -j $(nproc) sdk sdk=camd && \
    make -j $(nproc) sdk sdk=cgx && \
    make -j $(nproc) sdk sdk=guigfx && \
    make -j $(nproc) sdk sdk=mui && \
    make -j $(nproc) sdk sdk=p96 && \
    make -j $(nproc) sdk sdk=mcc_betterstring && \
    make -j $(nproc) sdk sdk=mcc_guigfx && \
    make -j $(nproc) sdk sdk=mcc_nlist && \
    make -j $(nproc) sdk sdk=mcc_texteditor && \
    make -j $(nproc) sdk sdk=mcc_thebar && \
    make -j $(nproc) sdk sdk=render && \
    make -j $(nproc) sdk sdk=warp3d && \
    make -j $(nproc) all-sdk && \
    wget https://raw.githubusercontent.com/aros-development-team/AROS/master/compiler/include/devices/newstyle.h -O newstyle.h && \
    wget https://raw.githubusercontent.com/aros-development-team/AROS/master/compiler/include/devices/sana2.h -O sana2.h && \
    wget https://raw.githubusercontent.com/aros-development-team/AROS/master/compiler/include/devices/sana2specialstats.h -O sana2specialstats.h && \
    wget https://dl.amigadev.com/newstyle.diff -O newstyle.diff && \
    patch --ignore-whitespace < newstyle.diff && \
    mv -fv newstyle.h sana2.h sana2specialstats.h /opt/${PATHPREFIX}/m68k-amigaos/ndk-include/devices/ && \
    cd / && \
    rm -rf /root/amiga-gcc && \
    apt-get purge -y \
    autoconf \
    bison \
    flex \
    g++ \
    g++-15 \
    gcc \
    gcc-15 \
    gettext \
    git \
    libgmp-dev \
    libmpfr-dev \
    libmpc-dev \
    libncurses-dev \
    make \
    rsync \
    texinfo\
    wget \
    && apt-get -y autoremove

ENV PATH /opt/${PATHPREFIX}/bin:$PATH
