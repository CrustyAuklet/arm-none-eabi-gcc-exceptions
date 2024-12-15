# based on build instructions from https://gitlab.arm.com/tooling/gnu-devtools-for-arm
FROM ubuntu:22.04

ENV TZ="America/Los_Angeles"
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get -y update \
    && apt-get install -y \
        git-core \
        autoconf \
        wget \
        build-essential \
        libgmp-dev \
        libmpfr-dev \
        libncurses5-dev \
        libmpc-dev \
        flex \
        bison \
        byacc \
        python3 \
        python3-dev \
        texinfo \
        # used in build-newlib-for-mingw-toolchain.sh
        rsync \
        mingw-w64 \
    && apt-get autoremove --purge -y \
    && apt-get autoclean -y \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

ENV HOME=/root
WORKDIR $HOME

RUN mkdir src && git clone https://git.gitlab.arm.com/tooling/gnu-devtools-for-arm.git ./src/gnu-devtools-for-arm

RUN wget -qO- https://developer.arm.com/-/media/Files/downloads/gnu/13.3.rel1/srcrel/arm-gnu-toolchain-src-snapshot-13.3.rel1.tar.xz | tar -xvJ -C ./src

ENV PATH="$HOME/src/gnu-devtools-for-arm:$PATH"

RUN sed -i -e 's/fno-exceptions/fexceptions/g' $HOME/src/gnu-devtools-for-arm/build-*.sh

# builds into $HOME/src/build-arm-none-eabi
RUN build-gnu-toolchain.sh --target=arm-none-eabi --aprofile  --rmprofile -- -j 20 --release --package --enable-newlib-nano --enable-gdb-with-python=yes

# If you are compiling in WSL2, these defines are necessary for building GMP. Otherwise the wrong compiler
# is used and you get a config error about not being able to determine the right executable extension.
# ENV CC_FOR_BUILD=/usr/bin/gcc
# ENV CPP_FOR_BUILD=/usr/bin/cpp
#
# Also you may need to make sure that the posix thread model version of mingw is selected, using
# update-alternatives, this wasn't needed to complete the build in this docker based build process
# sudo update-alternatives --config x86_64-w64-mingw32-g++
# sudo update-alternatives --config x86_64-w64-mingw32-gcc

RUN mkdir -p build-mingw-arm-none-eabi \
    && build-gnu-toolchain.sh --target=arm-none-eabi -- \
    --builddir=$PWD/build-mingw-arm-none-eabi \
    --config-flags-host-tools=--host=x86_64-w64-mingw32 \
    --host-toolchain-path=$PWD/build-arm-none-eabi/install/bin

RUN build-newlib-for-mingw-toolchain.sh --target=arm-none-eabi --builddir=$PWD/build-mingw-arm-none-eabi -- \
    --enable-newlib-nano \
    --config-flags-gcc=--with-multilib-list=aprofile,rmprofile
