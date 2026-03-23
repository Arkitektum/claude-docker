FROM ubuntu:24.04

ARG TZ
ENV TZ="$TZ"

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
    # Firewall
    sudo \
    iptables \
    ipset \
    iproute2 \
    dnsutils \
    aggregate \
    # Playwright chromium dependencies (ubuntu 24.04 x64)
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

# Install Go
ARG GO_VERSION=1.25.5
RUN wget -q https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz -O /tmp/go.tar.gz && \
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
    groupadd -g ${LOCAL_GID} ${LOCAL_USER} 2>/dev/null || true && \
    useradd -m -u ${LOCAL_UID} -g ${LOCAL_GID} -s /bin/bash ${LOCAL_USER} && \
    mkdir -p /home/${LOCAL_USER}/.claude && \
    chown ${LOCAL_USER}:${LOCAL_USER} /home/${LOCAL_USER}/.claude
ENV HOME=/home/${LOCAL_USER}

ENV DISABLE_AUTOUPDATER=1 \
    DISABLE_TELEMETRY=1 \
    DISABLE_ERROR_REPORTING=1

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

# Install Claude Code
RUN curl -fsSL https://claude.ai/install.sh | bash

# Install Terraform MCP Server
RUN go install github.com/hashicorp/terraform-mcp-server/cmd/terraform-mcp-server@latest

# Marketplace plugin seed (built by seed-plugins.sh on host before docker build)
COPY --chown=${LOCAL_USER}:${LOCAL_USER} plugin-seed/seed/ /opt/claude-plugin-seed/
COPY --chown=${LOCAL_USER}:${LOCAL_USER} setup-plugins.sh /usr/local/bin/

# Firewall and managed settings
USER root
COPY init-firewall.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/init-firewall.sh /usr/local/bin/setup-plugins.sh && \
    echo "${LOCAL_USER} ALL=(root) NOPASSWD: /usr/local/bin/init-firewall.sh" > /etc/sudoers.d/firewall && \
    chmod 0440 /etc/sudoers.d/firewall

# Auto-enable seeded plugins via managed settings
RUN mkdir -p /etc/claude-code && \
    echo '{"enabledPlugins":{"arkitektum-mandatory@arkitektum-marketplace":true}}' > /etc/claude-code/managed-settings.json

# Container instructions injected into Claude's system prompt
COPY container.md /tmp/container.md
COPY claude-wrapper.sh /usr/local/bin/claude-wrapper
RUN chmod +x /usr/local/bin/claude-wrapper && \
    { cat /tmp/container.md; \
      echo ""; echo "## Firewall allowlist"; echo ""; \
      echo "GitHub IPs are fetched dynamically from api.github.com/meta. Additional allowed domains:"; echo ""; \
      grep -oP '"\K[a-z0-9][-a-z0-9.]*\.[a-z]{2,}' /usr/local/bin/init-firewall.sh | sort -u | sed 's/^/- /' ; \
    } > /etc/claude-code/container.md && \
    rm /tmp/container.md && \
    chmod 0444 /etc/claude-code/container.md
USER ${LOCAL_USER}

WORKDIR /app
