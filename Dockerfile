FROM archlinux:base-devel

ARG TZ=Asia/Vladivostok
ARG DOCKER_HOST_UID=1000
ARG DOCKER_HOST_GID=1000
ARG DOCKER_USER=developer
ARG DOCKER_USER_HOME=/home/developer
ARG MIRROR_LIST_COUNTRY=DE
ARG COC_EXTENSIONS
ARG BUILD_PACKAGES

RUN echo "* soft core 0" >> /etc/security/limits.conf && \
    echo "* hard core 0" >> /etc/security/limits.conf && \
    echo "* soft nofile 10000" >> /etc/security/limits.conf
RUN sed -i 's/^UID_MAX.*/UID_MAX 999999999/' /etc/login.defs
RUN sed -i 's/^GID_MAX.*/GID_MAX 999999999/' /etc/login.defs
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime
RUN set -eux; \
	groupadd $DOCKER_USER --gid=$DOCKER_HOST_GID && \
	useradd --no-log-init -g $DOCKER_USER --uid=$DOCKER_HOST_UID \
  -d $DOCKER_USER_HOME -ms /bin/bash $DOCKER_USER
RUN set -eux; \
  tmp="$(mktemp)"; \
  if curl -fsSL \
      --connect-timeout 10 \
      --max-time 30 \
      --retry 5 \
      --retry-delay 1 \
      --retry-all-errors \
      "https://archlinux.org/mirrorlist/?country=${MIRROR_LIST_COUNTRY}&protocol=https&ip_version=4&use_mirror_status=on" \
    | sed -e 's/^\s*#Server/Server/' -e '/^\s*#/d' \
    > "$tmp" \
    && grep -q '^Server' "$tmp"; then \
      mv "$tmp" /etc/pacman.d/mirrorlist; \
  else \
      echo "WARN: mirrorlist update failed; keeping existing /etc/pacman.d/mirrorlist" >&2; \
      rm -f "$tmp"; \
  fi
RUN set -eux; \
    : "${BUILD_PACKAGES:?BUILD_PACKAGES build arg must be set}"; \
    sed -Ei \
        -e '/^[[:space:]]*DisableSandbox[[:space:]]*$/d' \
        -e '/^[[:space:]]*DisableDownloadTimeout[[:space:]]*$/d' \
        -e '/^[[:space:]]*ParallelDownloads[[:space:]]*=/d' \
        /etc/pacman.conf; \
    sed -i '/^\[options\]$/a ParallelDownloads = 1' /etc/pacman.conf; \
    sed -i '/^\[options\]$/a DisableDownloadTimeout' /etc/pacman.conf; \
    sed -i '/^\[options\]$/a DisableSandbox' /etc/pacman.conf; \
    pacman -Syu --noconfirm --needed $BUILD_PACKAGES; \
    pacman -Scc --noconfirm; \
    rm -rf /var/lib/pacman/sync/*
RUN echo "${DOCKER_USER} ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

RUN mkdir -p \
    /workspace \
    $DOCKER_USER_HOME/.codex \
    $DOCKER_USER_HOME/.gemini \
    $DOCKER_USER_HOME/.config \
    $DOCKER_USER_HOME/.cache/vim \
    $DOCKER_USER_HOME/.cache/uv \
    $DOCKER_USER_HOME/.local/share/uv && \
  chown -R $DOCKER_USER:$DOCKER_USER \
    /workspace \
    $DOCKER_USER_HOME/.codex \
    $DOCKER_USER_HOME/.gemini \
    $DOCKER_USER_HOME/.config \
    $DOCKER_USER_HOME/.cache \
    $DOCKER_USER_HOME/.local

ENV PYTHONUNBUFFERED=1
ENV HOME=$DOCKER_USER_HOME
ENV EDITOR=vim
ENV TERM=xterm-256color

USER ${DOCKER_HOST_UID}:${DOCKER_HOST_GID}

RUN mkdir -p "$DOCKER_USER_HOME/.local/share" && \
    git clone --depth=1 \
      https://github.com/Aloxaf/fzf-tab.git \
      "$DOCKER_USER_HOME/.local/share/fzf-tab"
COPY --chown=$DOCKER_USER:$DOCKER_USER \
  .zshrc $DOCKER_USER_HOME/.zshrc
COPY --chown=$DOCKER_USER:$DOCKER_USER \
  .tmux.conf $DOCKER_USER_HOME/.tmux.conf

RUN curl -fLo $DOCKER_USER_HOME/.vim/autoload/plug.vim --create-dirs \
  https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
COPY --chown=$DOCKER_USER:$DOCKER_USER .vimrc $DOCKER_USER_HOME/.vimrc
RUN cat $DOCKER_USER_HOME/.vimrc \
  |sed -n '/plug#begin/,/plug#end/p' > $DOCKER_USER_HOME/.vimrc_plug
RUN vim -u $DOCKER_USER_HOME/.vimrc_plug +'PlugInstall --sync' +qa
RUN set -eux; \
    : "${COC_EXTENSIONS:?COC_EXTENSIONS build arg must be set}"; \
    vim -u $DOCKER_USER_HOME/.vimrc_plug \
      +"CocInstall -sync ${COC_EXTENSIONS}" +qa
COPY --chown=$DOCKER_USER:$DOCKER_USER .coc-settings.json \
  $DOCKER_USER_HOME/.vim/coc-settings.json

WORKDIR /workspace
