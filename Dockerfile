FROM amigadev/docker-base:latest
WORKDIR /root
COPY ./ ./

RUN export DEBIAN_FRONTEND=noninteractive && \
    apt update && \
    apt install -y gcc-15 g++-15 lhasa && \
    rm -rf /var/lib/apt/lists/* && \
    make update PREFIX=/opt/m68k-amigaos && \
    make -j4 GDB_CC=gcc-15 GDB_CXX=g++-15 all PREFIX=/opt/m68k-amigaos && \
    make -j4 all-sdk PREFIX=/opt/m68k-amigaos && \
    wget https://raw.githubusercontent.com/aros-development-team/AROS/master/compiler/include/devices/sana2.h -O sana2.h && \
    wget https://raw.githubusercontent.com/aros-development-team/AROS/master/compiler/include/devices/sana2specialstats.h -O sana2specialstats.h && \
    mv -fv sana2.h sana2specialstats.h /opt/m68k-amigaos/m68k-amigaos/ndk-include/devices/ && \
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
