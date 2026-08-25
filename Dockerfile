FROM amigadev/docker-base:latest
WORKDIR /root
COPY ./ ./
ARG PATHPREFIX="m68k-amigaos"
ARG BINUTILS_BRANCH="amiga-2.46"
ARG GCC_BRANCH="amiga6"

RUN export DEBIAN_FRONTEND=noninteractive && \
    export HOST_ARCH=$(gcc -dumpmachine 2>/dev/null || dpkg-architecture -qDEB_HOST_GNU_TYPE) && \
    export PREFIX=/opt/${PATHPREFIX} && \
    apt update && \
    apt install -y gcc-15 g++-15 lhasa && \
    rm -rf /var/lib/apt/lists/* && \
    echo "HOST_ARCH: ${HOST_ARCH}" && \
    echo "PREFIX: ${PREFIX}" && \
    echo "BINUTILS_BRANCH: ${BINUTILS_BRANCH}" && \
    make NDK=3.9 update && \
    make NDK=3.9 make branch mod=binutils branch=${BINUTILS_BRANCH} && \
    make NDK=3.9 make branch mod=gcc branch=${GCC_BRANCH} && \
    make -j $(nproc) NDK=3.9 GDB_CC=gcc-15 GDB_CXX=g++-15 all && \
    make -j $(nproc) NDK=3.9 sdk sdk=filesysbox && \
    make -j $(nproc) NDK=3.9 sdk sdk=sdi && \
    make -j $(nproc) NDK=3.9 sdk sdk=ahi && \
    make -j $(nproc) NDK=3.9 sdk sdk=mhi && \
    make -j $(nproc) NDK=3.9 sdk sdk=camd && \
    make -j $(nproc) NDK=3.9 sdk sdk=cgx && \
    make -j $(nproc) NDK=3.9 sdk sdk=guigfx && \
    make -j $(nproc) NDK=3.9 sdk sdk=mui && \
    make -j $(nproc) NDK=3.9 sdk sdk=p96 && \
    make -j $(nproc) NDK=3.9 sdk sdk=mcc_betterstring && \
    make -j $(nproc) NDK=3.9 sdk sdk=mcc_guigfx && \
    make -j $(nproc) NDK=3.9 sdk sdk=mcc_nlist && \
    make -j $(nproc) NDK=3.9 sdk sdk=mcc_texteditor && \
    make -j $(nproc) NDK=3.9 sdk sdk=mcc_thebar && \
    make -j $(nproc) NDK=3.9 sdk sdk=render && \
    make -j $(nproc) NDK=3.9 sdk sdk=warp3d && \
    make -j $(nproc) NDK=3.9 all-sdk && \
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
    lhasa \
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

