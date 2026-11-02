# syntax=docker/dockerfile:1
# Build context is the repository root:
#   docker build -f docker/Dockerfile -t magmakomer/claude-dev:<version> .

ARG NODE_VERSION=24.22.2
FROM node:${NODE_VERSION}-bookworm-slim

ARG GH_VERSION=2.103.3
ARG CLAUDE_CODE_VERSION=2.1.309
ARG DEV_UID=1000
ARG DEV_GID=1000

ENV DEBIAN_FRONTEND=noninteractive

# Base tooling + GitHub CLI from its official apt repository (pinned version).
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      bash ca-certificates curl git gnupg jq less openssh-client procps \
      python3 python3-pip python3-venv ripgrep unzip \
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

# Non-root user. The node base image ships a "node" user at UID 1000; replace it.
RUN userdel -r node \
 && groupadd --gid "${DEV_GID}" dev \
 && useradd --uid "${DEV_UID}" --gid "${DEV_GID}" --create-home --shell /bin/bash dev \
 && mkdir -p /workspace \
 && chown dev:dev /workspace

COPY --chmod=0755 scripts/entrypoint.sh scripts/healthcheck.sh /usr/local/bin/

USER dev
ENV HOME=/home/dev \
    PATH=/home/dev/.local/bin:${PATH} \
    DISABLE_AUTOUPDATER=1

# Claude Code via Anthropic's official native installer, pinned to a version.
RUN curl -fsSL https://claude.ai/install.sh | bash -s "${CLAUDE_CODE_VERSION}"

WORKDIR /workspace
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
