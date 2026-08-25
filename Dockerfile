FROM amigadev/docker-base:latest
WORKDIR /root
COPY ./ ./

RUN export DEBIAN_FRONTEND=noninteractive && \
    apt update && \
    apt install -y gcc-15 g++-15 lhasa && \
    rm -rf /var/lib/apt/lists/* && \
    make NDK=3.9 update PREFIX=/opt/m68k-amigaos && \
    make -j $(nproc) NDK=3.9 GDB_CC=gcc-15 GDB_CXX=g++-15 all PREFIX=/opt/m68k-amigaos && \
    make -j $(nproc) NDK=3.9 sdk sdk=filesysbox PREFIX=/opt/m68k-amigaos && \
    make -j $(nproc) NDK=3.9 sdk sdk=sdi PREFIX=/opt/m68k-amigaos && \
    make -j $(nproc) NDK=3.9 sdk sdk=ahi PREFIX=/opt/m68k-amigaos && \
    make -j $(nproc) NDK=3.9 sdk sdk=mhi PREFIX=/opt/m68k-amigaos && \
    make -j $(nproc) NDK=3.9 sdk sdk=camd PREFIX=/opt/m68k-amigaos && \
    make -j $(nproc) NDK=3.9 sdk sdk=cgx PREFIX=/opt/m68k-amigaos && \
    make -j $(nproc) NDK=3.9 sdk sdk=guigfx PREFIX=/opt/m68k-amigaos && \
    make -j $(nproc) NDK=3.9 sdk sdk=mui PREFIX=/opt/m68k-amigaos && \
    make -j $(nproc) NDK=3.9 sdk sdk=p96 PREFIX=/opt/m68k-amigaos && \
    make -j $(nproc) NDK=3.9 sdk sdk=mcc_betterstring PREFIX=/opt/m68k-amigaos && \
    make -j $(nproc) NDK=3.9 sdk sdk=mcc_guigfx PREFIX=/opt/m68k-amigaos && \
    make -j $(nproc) NDK=3.9 sdk sdk=mcc_nlist PREFIX=/opt/m68k-amigaos && \
    make -j $(nproc) NDK=3.9 sdk sdk=mcc_texteditor PREFIX=/opt/m68k-amigaos && \
    make -j $(nproc) NDK=3.9 sdk sdk=mcc_thebar PREFIX=/opt/m68k-amigaos && \
    make -j $(nproc) NDK=3.9 sdk sdk=render PREFIX=/opt/m68k-amigaos && \
    make -j $(nproc) NDK=3.9 sdk sdk=warp3d PREFIX=/opt/m68k-amigaos && \
    make -j $(nproc) NDK=3.9 all-sdk PREFIX=/opt/m68k-amigaos && \
    wget https://raw.githubusercontent.com/aros-development-team/AROS/master/compiler/include/devices/newstyle.h -O newstyle.h && \
    wget https://raw.githubusercontent.com/aros-development-team/AROS/master/compiler/include/devices/sana2.h -O sana2.h && \
    wget https://raw.githubusercontent.com/aros-development-team/AROS/master/compiler/include/devices/sana2specialstats.h -O sana2specialstats.h && \
    wget https://dl.amigadev.com/newstyle.diff -O newstyle.diff && \
    patch --ignore-whitespace < newstyle.diff && \
    mv -fv newstyle.h sana2.h sana2specialstats.h /opt/m68k-amigaos/m68k-amigaos/ndk-include/devices/ && \
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

ENV PATH /opt/m68k-amigaos/bin:$PATH
