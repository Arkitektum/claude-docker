FROM ubuntu:24.04

ARG TZ
ENV TZ="$TZ"

# Prefer IPv4 over IPv6 to prevent apt and other tools from stalling on IPv6 connections
RUN echo 'precedence ::ffff:0:0/96  100' >> /etc/gai.conf

# Use Norwegian mirror on x86 (default Ubuntu mirrors may be unreachable over IPv6 or port 80).
# arm64 (Apple Silicon) builds pull from ports.ubuntu.com, which ftp.uninett.no does not
# mirror, so those sources are left alone. The regex would also mangle "/ubuntu-ports/".
RUN if [ "$(dpkg --print-architecture)" = "amd64" ]; then \
      sed -i 's|http://[^ ]*/ubuntu/\?|http://ftp.uninett.no/ubuntu/ |g' /etc/apt/sources.list.d/ubuntu.sources; \
    fi

# Install dependencies
RUN DEBIAN_FRONTEND=noninteractive apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    curl \
    ca-certificates \
    git \
    ripgrep \
    jq \
    python3-pip \
    python3-venv \
    wget \
    tree \
    postgresql-client \
    libgcc-s1 \
    libgssapi-krb5-2 \
    libicu74 \
    libssl3t64 \
    tzdata \
    zlib1g \
    # Proxy and firewall
    squid \
    sudo \
    iptables \
    iproute2 \
    dnsutils \
    # Playwright chromium dependencies (ubuntu 24.04)
    libasound2t64 \
    libatk-bridge2.0-0t64 \
    libatk1.0-0t64 \
    libatspi2.0-0t64 \
    libcairo2 \
    libcups2t64 \
    libdbus-1-3 \
    libdrm2 \
    libgbm1 \
    libglib2.0-0t64 \
    libnspr4 \
    libnss3 \
    libpango-1.0-0 \
    libx11-6 \
    libxcb1 \
    libxcomposite1 \
    libxdamage1 \
    libxext6 \
    libxfixes3 \
    libxkbcommon0 \
    libxrandr2 \
    && rm -rf /var/lib/apt/lists/*

# Install Go (dpkg arch names match Go's: amd64, arm64)
ARG GO_VERSION=1.25.5
RUN GOARCH="$(dpkg --print-architecture)" && \
    wget -q "https://go.dev/dl/go${GO_VERSION}.linux-${GOARCH}.tar.gz" -O /tmp/go.tar.gz && \
    tar -C /usr/local -xzf /tmp/go.tar.gz && \
    rm /tmp/go.tar.gz
ENV PATH="/usr/local/go/bin:${PATH}"

# Install latest .NET SDK
RUN wget -q https://dot.net/v1/dotnet-install.sh -O /tmp/dotnet-install.sh && \
    chmod +x /tmp/dotnet-install.sh && \
    /tmp/dotnet-install.sh --version latest --install-dir /usr/local/dotnet && \
    rm /tmp/dotnet-install.sh
ENV PATH="/usr/local/dotnet:${PATH}"
ENV DOTNET_ROOT="/usr/local/dotnet"
ENV DOTNET_CLI_TELEMETRY_OPTOUT="1"

ARG LOCAL_USER=claude
ARG LOCAL_UID=1000
ARG LOCAL_GID=1000

# Create user matching host (delete Ubuntu 24.04's default ubuntu:1000 if it exists)
RUN (userdel -r ubuntu 2>/dev/null || true) && \
    (groupdel ubuntu 2>/dev/null || true) && \
    groupadd -g ${LOCAL_GID} ${LOCAL_USER} 2>/dev/null || true && \
    useradd -m -u ${LOCAL_UID} -g ${LOCAL_GID} -s /bin/bash ${LOCAL_USER} && \
    mkdir -p /home/${LOCAL_USER}/.claude && \
    chown ${LOCAL_UID}:${LOCAL_GID} /home/${LOCAL_USER}/.claude
ENV HOME=/home/${LOCAL_USER}

ENV DISABLE_AUTOUPDATER=1 \
    DISABLE_TELEMETRY=1 \
    DISABLE_ERROR_REPORTING=1 \
    CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1

ENV PATH="/home/${LOCAL_USER}/.local/bin:${PATH}" \
    GOBIN="/home/${LOCAL_USER}/.local/bin"

USER ${LOCAL_USER}

# Install nvm and Node.js, with a stable symlink for PATH
ARG NODE_VERSION=24
ENV NVM_DIR="/home/${LOCAL_USER}/.nvm"
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash && \
    . "$NVM_DIR/nvm.sh" && nvm install ${NODE_VERSION} && \
    ln -s "$(dirname "$(nvm which node)")" "$NVM_DIR/current"
ENV PATH="${NVM_DIR}/current:${PATH}"

# Install uv (Python package manager)
RUN curl -LsSf https://astral.sh/uv/install.sh | sh

# Install Rust
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/home/${LOCAL_USER}/.cargo/bin:${PATH}"

# Install Playwright and Chromium browser
RUN uv tool install playwright && playwright install chromium

# Install Claude Code (optionally pinned via CLAUDE_CODE_VERSION: stable|latest|X.Y.Z)
ARG CLAUDE_CODE_VERSION=latest
RUN curl -fsSL https://claude.ai/install.sh | bash -s -- "${CLAUDE_CODE_VERSION}"

# Install Terraform MCP Server (copy binary from official Docker image)
COPY --from=hashicorp/terraform-mcp-server:0.5.1 --chmod=755 /bin/terraform-mcp-server /home/${LOCAL_USER}/.local/bin/terraform-mcp-server

# Squid proxy, entrypoint, and managed settings
USER root
COPY squid.conf /etc/squid/squid.conf
COPY allowed_domains.txt /etc/squid/allowed_domains.txt
COPY init-proxy.sh /usr/local/bin/init-proxy.sh
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY container-info.sh /usr/local/bin/container-info.sh
COPY apt-safe /usr/local/bin/apt-safe
RUN chmod +x /usr/local/bin/init-proxy.sh /usr/local/bin/entrypoint.sh /usr/local/bin/container-info.sh && \
    chmod 0555 /usr/local/bin/apt-safe && \
    chmod 0444 /etc/squid/squid.conf && \
    chmod 0644 /etc/squid/allowed_domains.txt && \
    echo "${LOCAL_USER} ALL=(root) NOPASSWD:SETENV: /usr/local/bin/init-proxy.sh" > /etc/sudoers.d/init-proxy && \
    echo "${LOCAL_USER} ALL=(root) NOPASSWD: /usr/local/bin/apt-safe" > /etc/sudoers.d/apt-safe && \
    chmod 0440 /etc/sudoers.d/init-proxy /etc/sudoers.d/apt-safe

# Make build arg available at runtime for init-proxy.sh
ENV LOCAL_USER=${LOCAL_USER}

# Managed settings: enable plugins + inject container instructions via SessionStart hook
RUN mkdir -p /etc/claude-code && \
    echo '{"enabledPlugins":{"arkitektum-mandatory@arkitektum-marketplace":true},"hooks":{"SessionStart":[{"matcher":"","hooks":[{"type":"command","command":"/usr/local/bin/container-info.sh"}]}]}}' \
    > /etc/claude-code/managed-settings.json

# Container documentation base (the Network section + allowlist are appended at
# runtime by container-info.sh, which reflects whether the firewall is active).
COPY container.md /etc/claude-code/container.md
RUN chmod 0444 /etc/claude-code/container.md

# User-provided customization script (staged by claude-docker from $CLAUDE_DOCKER_CUSTOMIZE).
# Runs as root with direct network access (no proxy/firewall during build).
COPY customize.sh /tmp/customize.sh
RUN chmod +x /tmp/customize.sh && /tmp/customize.sh && rm /tmp/customize.sh

USER ${LOCAL_USER}
WORKDIR /app

# Proxy env vars for runtime. Must remain after all RUN commands
# to avoid affecting the build (no proxy exists during build).
ENV http_proxy="http://127.0.0.1:3128" \
    https_proxy="http://127.0.0.1:3128" \
    HTTP_PROXY="http://127.0.0.1:3128" \
    HTTPS_PROXY="http://127.0.0.1:3128" \
    no_proxy="localhost,127.0.0.1,container.local" \
    NO_PROXY="localhost,127.0.0.1,container.local"

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["sleep", "infinity"]
