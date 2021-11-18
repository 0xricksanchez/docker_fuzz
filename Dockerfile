FROM ubuntu:rolling
LABEL maintainer="Christopher Krah <admin@0x434b.dev>"

ENV DEBIAN_FRONTEND noninteractive

# Ensure basic tools and the latest LLVM are present so that AFL can use clang-lto (requires >= LLVM 11)
RUN rm /etc/dpkg/dpkg.cfg.d/excludes \
    && apt-get update \
    && apt-get install -y git gnupg2 wget curl ca-certificates build-essential sudo python3 python3-dev python3-setuptools \
                       rsync bison gperf autoconf libtool libtool-bin texinfo gettext flex openssh-server ncat neovim \
                       apt-utils tmux htop man manpages-posix-dev gdb zsh python-is-python3 libpixman-1-dev gcc gdb-multiarch \
                       gcc-9-plugin-dev cgroup-tools autopoint pkg-config libz-dev libssl-dev liblzma-dev libcrypto++-dev \
                       libbz2-dev cmake make binutils-dev ninja-build \
    && apt-get install -y -o Dpkg::Options::="--force-overwrite" bat ripgrep hexyl httpie \
    && ln -s $(which batcat) /usr/bin/bat \
    && apt-get install -y python3.9 python3.9-dev libpython3.9 libpython3.9-dev \
    && wget -O - https://apt.llvm.org/llvm-snapshot.gpg.key|sudo apt-key add - \
    && echo deb http://apt.llvm.org/hirsute/ llvm-toolchain-hirsute-13 main >> /etc/apt/sources.list \
    && echo deb-src http://apt.llvm.org/hirsute/ llvm-toolchain-hirsute-13 main >> /etc/apt/sources.list \
    && apt-get update && \
    apt-get install -y clang-13 clang-tools-13 libc++1-13 libc++-13-dev libc++abi1-13 libc++abi-13-dev libclang1-13 \
                    libclang-13-dev libclang-common-13-dev libclang-cpp13 libclang-cpp13-dev liblld-13 liblld-13-dev \
                    liblldb-13 liblldb-13-dev libllvm13 libomp-13-dev libomp5-13 lld-13 lldb-13 python3-lldb-13 \
                    llvm-13 llvm-13-dev llvm-13-runtime llvm-13-tools \
    && rm -rf /var/lib/apt/lists \
    && apt-get clean \
    && echo y | unminimize

# Create a sensible user
RUN useradd --create-home --groups sudo --shell $(which zsh) pleb && echo "pleb ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# Make sure directory exists
RUN mkdir /var/run/sshd

# Remaining installations can be done from here
WORKDIR /home/pleb/
USER pleb
RUN chown -R pleb:pleb /home/pleb/ && mkdir tools
WORKDIR /home/pleb/tools/

# Install pwndbg for debugging 
RUN git clone --depth=1 https://github.com/pwndbg/pwndbg && cd pwndbg && chmod +x setup.sh && echo y | ./setup.sh && cd ../

# Install honggfuzz
USER root
RUN apt-get -y update && apt-get install -y make pkg-config libipt-dev libunwind8-dev binutils-dev \
    && git clone --depth=1 https://github.com/google/honggfuzz.git && cd honggfuzz && make && sudo make install && cd ../ 

# Install AFL++
RUN apt-get install -y gcc-$(gcc --version|head -n1|sed 's/.* //'|sed 's/\..*//')-plugin-dev libstdc++-$(gcc --version|head -n1|sed 's/.* //'|sed 's/\..*//')-dev \
    && update-alternatives --install /usr/bin/clang           clang $(which clang-13) 1 \
    && update-alternatives --install /usr/bin/clang++         clang++ $(which clang++-13) 1 \ 
    && update-alternatives --install /usr/bin/llvm-config     llvm-config $(which llvm-config-13) 1 \
    && update-alternatives --install /usr/bin/llvm-symbolizer llvm-symbolizer $(which llvm-symbolizer-13) 1 \
    && update-alternatives --install /usr/bin/llvm-cov        llvm-cov $(which llvm-cov-13) 1 \
    && update-alternatives --install /usr/bin/llvm-profdata   llvm-profdata $(which llvm-profdata-13) 1 \
    && git clone --depth=1 https://github.com/AFLplusplus/AFLplusplus && cd AFLplusplus && make distrib && make install && cd ../

# Install radamsa
RUN git clone --depth=1 https://gitlab.com/akihe/radamsa.git && cd radamsa && make && make install && cd ../

# Install rr for time travel debugging
# TODO https://github.com/rr-debugger/rr/issues/2987
RUN apt-get install -y ccache cmake make g++-multilib gdb pkg-config coreutils python3-pexpect manpages-dev git \
                       ninja-build capnproto libcapnp-dev \
    && git clone --depth=1 https://github.com/rr-debugger/rr.git && cd rr \ 
    && sed -i s/"\-Werror"/""/g CMakeLists.txt && mkdir obj && cd obj && \ 
    CC=clang CXX=clang++ cmake -G Ninja ../ && cmake --build . && cmake --build . --target install

# Install crashwalk and exploitable
USER pleb
WORKDIR /tmp
ARG VERSION=1.17.3
ARG MACHINE=amd64
RUN wget https://golang.org/dl/go$VERSION.linux-$MACHINE.tar.gz && tar -xf "go${VERSION}.linux-${MACHINE}.tar.gz" && sudo mv go /usr/local/ 
ENV GOPATH=$HOME/go
ENV PATH=$PATH:/usr/local/go/bin:$GOPATH/bin
WORKDIR /home/pleb/tools
ARG EXPL=/home/pleb/src/exploitable
USER root
WORKDIR /home/pleb/tools
RUN git clone --depth=1 https://github.com/jfoote/exploitable.git $EXPL && echo "/home/pleb/src/exploitable/exploitable/exploitable.py" >> /home/pleb/.gdbinit \
    && go get -u github.com/bnagy/crashwalk/cmd/...
USER pleb

# Let's ditch bash for zsh
RUN sh -c "$(wget -O- https://github.com/deluan/zsh-in-docker/releases/download/v1.1.2/zsh-in-docker.sh)"

EXPOSE 22
CMD ["/usr/bin/zsh"]
