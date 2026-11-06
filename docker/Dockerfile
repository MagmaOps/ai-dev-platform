# syntax=docker/dockerfile:1
# Build context is the repository root:
#   docker build -f docker/Dockerfile -t magmakomer/claude-dev:<version> .

ARG NODE_VERSION=24.22.2
FROM node:${NODE_VERSION}-bookworm-slim

ARG GH_VERSION=2.103.3
ARG CLAUDE_CODE_VERSION=2.1.309
ARG HERDR_VERSION=0.9.5
# SHA-256 of herdr-linux-x86_64 for HERDR_VERSION (from https://herdr.dev/latest.json). Update both together.
ARG HERDR_SHA256=14d9e8bc8b4a9e0118d77c32266f76d461f09b40342eb23752960bd89f59929d
ARG UV_VERSION=0.13.7
# SHA-256 of uv-x86_64-unknown-linux-gnu.tar.gz for UV_VERSION (the release's .sha256 asset). Update both together.
ARG UV_SHA256=c5221ff41b7892bfc223543883600125f6a47fe845093e0f5bdff4f359196d83
ARG DEV_UID=1000
ARG DEV_GID=1000

ENV DEBIAN_FRONTEND=noninteractive

# Base tooling + GitHub CLI from its official apt repository (pinned version).
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      bash ca-certificates curl git gnupg jq less openssh-client procps \
      python3 python3-pip python3-venv ripgrep tmux unzip \
 && install -d -m 0755 /etc/apt/keyrings \
 && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      -o /etc/apt/keyrings/githubcli-archive-keyring.gpg \
 && chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
 && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      > /etc/apt/sources.list.d/github-cli.list \
 && apt-get update \
 && apt-get install -y --no-install-recommends "gh=${GH_VERSION}" \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

# Herdr: terminal workspace manager that keeps agent sessions alive across disconnects.
# Pinned binary, verified against its published checksum (no piping an install script).
RUN curl -fsSL -o /usr/local/bin/herdr \
      "https://github.com/herdrdev/herdr/releases/download/v${HERDR_VERSION}/herdr-linux-x86_64" \
 && echo "${HERDR_SHA256}  /usr/local/bin/herdr" | sha256sum -c - \
 && chmod 0755 /usr/local/bin/herdr

# uv: installs a managed Python (the Debian system python is 3.11) and fast venvs without root.
# Pinned release, verified against its published checksum.
RUN curl -fsSL -o /tmp/uv.tar.gz \
      "https://github.com/astral-sh/uv/releases/download/${UV_VERSION}/uv-x86_64-unknown-linux-gnu.tar.gz" \
 && echo "${UV_SHA256}  /tmp/uv.tar.gz" | sha256sum -c - \
 && tar -xzf /tmp/uv.tar.gz -C /usr/local/bin --strip-components=1 uv-x86_64-unknown-linux-gnu/uv uv-x86_64-unknown-linux-gnu/uvx \
 && rm /tmp/uv.tar.gz

# Non-root user. The node base image ships a "node" user at UID 1000; replace it.
RUN userdel -r node \
 && groupadd --gid "${DEV_GID}" dev \
 && useradd --uid "${DEV_UID}" --gid "${DEV_GID}" --create-home --shell /bin/bash dev \
 && mkdir -p /workspace /home/dev/.claude \
 && chown dev:dev /workspace /home/dev/.claude

COPY --chmod=0755 scripts/entrypoint.sh scripts/healthcheck.sh scripts/install-skills.sh /usr/local/bin/
COPY --chmod=0755 scripts/new-agent.sh /usr/local/bin/new-agent
# User-level Claude Code instructions (loaded in every session, alongside the repo's own CLAUDE.md).
COPY --chown=dev:dev --chmod=0644 docker/user-claude.md /home/dev/.claude/CLAUDE.md

USER dev
ENV HOME=/home/dev \
    PATH=/home/dev/.local/bin:${PATH} \
    DISABLE_AUTOUPDATER=1

# Claude Code via Anthropic's official native installer, pinned to a version.
RUN curl -fsSL https://claude.ai/install.sh | bash -s "${CLAUDE_CODE_VERSION}"

WORKDIR /workspace
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
