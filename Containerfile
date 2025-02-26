FROM ubuntu:24.04

# Set non-interactive installation
ENV DEBIAN_FRONTEND=noninteractive

# Set environment variables
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
ENV TZ=UTC

# Install required packages
RUN apt-get update && apt-get install -y \
    bc \
    bison \
    build-essential \
    ccache \
    curl \
    flex \
    g++-multilib \
    gcc-multilib \
    git \
    git-lfs \
    gnupg \
    gperf \
    imagemagick \
    lib32ncurses5-dev \
    lib32readline-dev \
    lib32z1-dev \
    liblz4-tool \
    libncurses5 \
    libncurses5-dev \
    libsdl1.2-dev \
    libssl-dev \
    libxml2 \
    libxml2-utils \
    lzop \
    openjdk-11-jdk \
    pngcrush \
    python3 \
    python3-pip \
    rsync \
    schedtool \
    squashfs-tools \
    sudo \
    unzip \
    wget \
    xsltproc \
    xz-utils \
    zip \
    zlib1g-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install repo tool
RUN curl -o /usr/local/bin/repo https://storage.googleapis.com/git-repo-downloads/repo \
    && chmod a+x /usr/local/bin/repo

# Set up working directory
WORKDIR /src

# Create output directory
RUN mkdir -p /output

# Configure git
RUN git config --global user.email 'androidbuild@localhost' && \
    git config --global user.name 'androidbuild'