# Yak development container
# Includes all toolchains needed for yak-box, yak-map, and OpenCode development

FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV CI=true

# Install essential build tools first
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    curl \
    git \
    bash \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Install Go 1.26
RUN wget -q https://go.dev/dl/go1.26.0.linux-amd64.tar.gz && \
    tar -C /usr/local -xzf go1.26.0.linux-amd64.tar.gz && \
    rm go1.26.0.linux-amd64.tar.gz
ENV PATH="/usr/local/go/bin:${PATH}"
ENV GOPATH="/go"
ENV GO111MODULE=on

# Install Rust
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable
ENV PATH="/root/.cargo/bin:${PATH}"

# Add wasm targets
RUN . /root/.cargo/env && rustup target add wasm32-wasip1

# Install OpenCode CLI
RUN curl -fsSL https://opencode.ai/install | bash && \
    cp /root/.opencode/bin/opencode /usr/local/bin/opencode && \
    chmod +x /usr/local/bin/opencode

# Install yx (pre-built binary copied from host)
COPY yx /usr/local/bin/yx
RUN chmod +x /usr/local/bin/yx

# Trust any mounted workspace (container runs as root, repo owned by host user)
RUN git config --global --add safe.directory '*'

# Create workspace
WORKDIR /workspace

# Default shell
SHELL ["/bin/bash", "-lc"]

# Set default command (can be overridden)
CMD ["/bin/bash"]