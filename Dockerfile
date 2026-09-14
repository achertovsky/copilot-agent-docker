FROM node:22-bookworm

ARG USER_UID=1000
ARG USER_GID=1000

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    bash \
    ca-certificates \
    curl \
    git \
    openssh-client \
    jq \
    ripgrep \
    fd-find \
    less \
    nano \
    vim \
    unzip \
    zip \
    tar \
    gzip \
    bzip2 \
    xz-utils \
    procps \
    file \
    tree \
    make \
    gcc \
    g++ \
    python3 \
    python3-pip \
    python3-venv \
    php-cli \
    php-curl \
    php-mbstring \
    php-xml \
    php-zip \
    php-intl \
    golang-go \
    && rm -rf /var/lib/apt/lists/*

# GitHub CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      -o /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update \
    && apt-get install -y gh \
    && rm -rf /var/lib/apt/lists/*

# Composer
COPY --from=composer:2 /usr/bin/composer /usr/local/bin/composer

# Create a runtime user whose UID/GID can match the host user.
RUN if getent passwd "${USER_UID}" >/dev/null; then \
        userdel "$(getent passwd "${USER_UID}" | cut -d: -f1)" || true; \
    fi \
    && if getent group "${USER_GID}" >/dev/null; then \
        GROUP_NAME="$(getent group "${USER_GID}" | cut -d: -f1)"; \
    else \
        groupadd --gid "${USER_GID}" agent; \
        GROUP_NAME=agent; \
    fi \
    && useradd \
        --uid "${USER_UID}" \
        --gid "${USER_GID}" \
        --create-home \
        --shell /bin/bash \
        agent \
    && mkdir -p /workspace /home/agent/.copilot /home/agent/.config/gh \
    && chown -R agent:"${GROUP_NAME}" /home/agent /workspace

RUN npm install --global @github/copilot \
    && npm cache clean --force

ENV COPILOT_HOME=/home/agent/.copilot
ENV GH_CONFIG_DIR=/home/agent/.config/gh

USER agent
WORKDIR /workspace

ENTRYPOINT ["copilot"]
