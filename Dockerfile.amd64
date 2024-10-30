FROM amd64/debian:bookworm AS builder

ARG DEBIAN_FRONTEND=noninteractive

RUN DEBIAN_FRONTEND=${DEBIAN_FRONTEND} apt-get update && apt-get install -y build-essential bash curl locales

RUN dpkg --add-architecture arm64
RUN dpkg --add-architecture armel
RUN dpkg --add-architecture armhf

RUN DEBIAN_FRONTEND=${DEBIAN_FRONTEND} apt-get install -y --no-install-recommends \
    crossbuild-essential-arm64 \
    crossbuild-essential-armel \
    crossbuild-essential-armhf

RUN DEBIAN_FRONTEND=${DEBIAN_FRONTEND} apt-get install -y qemu-user-static qemu-user binfmt-support
RUN DEBIAN_FRONTEND=${DEBIAN_FRONTEND} apt-get install -y gdb-multiarch gcc-arm-none-eabi
RUN DEBIAN_FRONTEND=${DEBIAN_FRONTEND} apt-get install -y --no-install-recommends \
    cmake clang gcc g++ \
    gcc-x86-64-linux-gnu g++-x86-64-linux-gnu binutils-x86-64-linux-gnu \
    gcc-aarch64-linux-gnu g++-aarch64-linux-gnu binutils-aarch64-linux-gnu \
    gcc-arm-linux-gnueabihf g++-arm-linux-gnueabihf \
    libc6-dev-arm64-cross libc6-dev-armel-cross libc6-dev-armhf-cross libc6-dev-i386 \
    libdlib-dev libblas-dev libatlas-base-dev liblapack-dev libjpeg62-turbo-dev wget bzip2 \
    gfortran libgfortran5 libquadmath0 libquadmath0-amd64-cross libquadrule-dev \
    libboost-dev libboost-system-dev

# /usr/lib/gcc/x86_64-linux-gnu/12/include/quadmath.h

#RUN ln -sf $(which gcc) /usr/local/bin/gcc-aarch64-linux-gnu \
#    && ln -sf $(which g++) /usr/local/bin/g++-aarch64-linux-gnu

WORKDIR /app

COPY ./hello.c .
COPY ./quadmath.cpp .

#RUN aarch64-linux-gnu-gcc -static -static-libgcc -std=c++11 hello.c -o hello
RUN gcc -g -Wall -Wextra -Wunreachable-code -static  hello.c -o hello -lm -llapack -lblas -lpthread -lgfortran -lquadmath

#RUN aarch64-linux-gnu-g++ --std=gnu++20 -I/usr/lib/gcc/x86_64-linux-gnu/12 -I/usr/lib/gcc/x86_64-linux-gnu/12/include -fext-numeric-literals -static -lgfortran -lquadmath quadmath.cpp -o quadmath
RUN g++ -g -Wall -Wextra -Wunreachable-code -static quadmath.cpp -o qm -lm -llapack -lblas -lpthread -lgfortran -lquadmath
# RUN g++

# arm-none-eabi-gcc -static hello.c -o hello
# find / -name aarch64-linux-gnu-gcc-10
# find / -name quadmath*

# Keep the container running
CMD ["tail", "-f", "/dev/null"]