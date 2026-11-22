# Ripple Codespace image — Flutter SDK on Ubuntu.
FROM mcr.microsoft.com/devcontainers/base:ubuntu

# Install system dependencies used by Flutter/Dart toolchain
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl git unzip xz-utils zip libglu1-mesa \
    && rm -rf /var/lib/apt/lists/*

# Install Flutter
ARG FLUTTER_VERSION=stable
RUN git clone --depth 1 -b "${FLUTTER_VERSION}" https://github.com/flutter/flutter.git /opt/flutter \
    && /opt/flutter/bin/flutter --version \
    && echo "/opt/flutter/bin" >> /etc/profile

ENV PATH="/opt/flutter/bin:$PATH"

WORKDIR /workspaces/ripple
