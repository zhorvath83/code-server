# syntax = docker/dockerfile:1.4
# https://github.com/moby/buildkit/blob/master/frontend/dockerfile/docs/reference.md
FROM codercom/code-server:4.10.0 AS code-server

SHELL ["/bin/bash", "-c"]

USER coder

ARG ARCH=amd64

# renovate: datasource=github-releases depName=mikefarah/yq
ARG YQ_VERSION=v4.31.2

# renovate: datasource=github-releases depName=mozilla/sops
ARG SOPS_VERSION=v3.7.3

# renovate: datasource=github-releases depName=FiloSottile/age
ARG AGE_VERSION=v1.1.1

# renovate: datasource=golang-version
ARG GO_VERSION=1.19.4

ENV CODER_HOME="/home/coder"
ENV HOME=${CODER_HOME}
ENV ENTRYPOINTD=${HOME}/entrypoint.d
ENV DEFAULT_WORKSPACE=/projects

# code-server uses the Open-VSX extension gallery( https://open-vsx.org/ )
# https://github.com/coder/code-server/blob/main/docs/FAQ.md#how-do-i-use-my-own-extensions-marketplace
ENV EXTENSIONS_GALLERY='{"serviceUrl": "https://marketplace.visualstudio.com/_apis/public/gallery","cacheUrl": "https://vscode.blob.core.windows.net/gallery/index","itemUrl": "https://marketplace.visualstudio.com/items"}'

ARG GOPATH=$CODER_HOME/go
#ENV PATH=$PATH:/usr/local/go/bin

# https://andrei-calazans.com/posts/2021-06-23/passing-secrets-github-actions-docker
RUN --mount=type=secret,id=USERNAME \
    --mount=type=secret,id=MAILADDRESS \
    <<EOF
    mkdir ${CODER_HOME}/projects
    mkdir ${CODER_HOME}/.ssh
    mkdir ${CODER_HOME}/entrypoint.d
    chmod 700 ${CODER_HOME}/.ssh

    sudo apt-get update -y
    sudo apt-get install --assume-yes --no-install-recommends wget curl gnupg
    # Adding Hashicorp repo
    KEYRING=/usr/share/keyrings/hashicorp-archive-keyring.gpg
    wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee "$KEYRING" >/dev/null
    # Listing signing key
    gpg --no-default-keyring --keyring "$KEYRING" --list-keys
    echo "deb [signed-by=$KEYRING] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
        sudo tee /etc/apt/sources.list.d/hashicorp.list

    # Adding Node.js repo
    wget -qO- https://deb.nodesource.com/setup_19.x | sudo -E bash -

    sudo apt-get update -y
    # Installing npm for Prettier, apache2-utils for generating htpasswd, sshpass for ansible,
    sudo apt-get install --assume-yes --no-install-recommends \
        terraform \
        nodejs \
        net-tools \
        iputils-ping \
        jq \
        software-properties-common \
        python3 \
        python3-pip \
        build-essential \
        python3-dev \
        mc \
        ca-certificates \
        unzip \
        bzr \
        git-extras \
        apache2-utils \
        sshpass

    # Installing zsh
    curl -o- https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh >> ~/oh_my_zsh.sh
    echo 'y' | . ~/oh_my_zsh.sh
    rm -rf  ~/oh_my_zsh.sh
    git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
    sed -i "s/plugins=(git.*)$/plugins=(git zsh-syntax-highlighting zsh-autosuggestions)/" ~/.zshrc
    # default bash
    echo "dash dash/sh boolean false" | sudo debconf-set-selections
    sudo DEBIAN_FRONTEND=noninteractive dpkg-reconfigure dash

    sudo npm install --save-dev --save-exact prettier

    # pip
    sudo pip3 install --upgrade pip

    # Installing pre-commit, pre-commit-hooks, yamllint, ansible-core
    sudo pip install \
        pre-commit \
        pre-commit-hooks \
        python-Levenshtein \
        yamllint \
        ansible-core

    # Installing SOPS, a simple and flexible tool for managing secrets
    sudo wget -q "https://github.com/mozilla/sops/releases/download/${SOPS_VERSION}/sops-${SOPS_VERSION}.linux" -O /usr/local/bin/sops
    sudo chmod +x /usr/local/bin/sops

    # Installing age, a simple, modern and secure encryption tool. Used with SOPS.
    wget -q "https://github.com/FiloSottile/age/releases/latest/download/age-${AGE_VERSION}-linux-${ARCH}.tar.gz" -O /tmp/age.tar.gz
    sudo tar -C /usr/local/bin -xzf /tmp/age.tar.gz --strip-components 1
    sudo chmod +x /usr/local/bin/age
    sudo chmod +x /usr/local/bin/age-keygen

    # Installing yq, a command-line YAML, JSON and XML processor
    sudo wget -q "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64" -O /usr/local/bin/yq
    sudo chmod +x /usr/local/bin/yq

    # Golang for Go-Task
    export GOPKG="go${GO_VERSION}.linux-${ARCH}.tar.gz"; \
        wget -q "https://golang.org/dl/${GOPKG}" -O /tmp/${GOPKG}
    sudo tar -C /usr/local -xzf "/tmp/${GOPKG}"
    mkdir -p "${GOPATH}"
    #go version
    echo "export GOPATH=$GOPATH" | tee -a "$CODER_HOME/.profile"
    echo "export PATH=$PATH:$HOME/bin:$HOME/.local/bin:$GOPATH/bin:/usr/local/go/bin" | tee -a "$CODER_HOME/.profile"

    # echo "export GOPATH=$GOPATH" | tee -a "$CODER_HOME/.profile"
    # echo "export PATH=$GOPATH/bin:$PATH" | tee -a "$CODER_HOME/.profile"
    # echo "export PATH=$PATH:/usr/local/go/bin" | tee -a "$CODER_HOME/.profile"
    # echo "export PATH=$PATH:/usr/local/go/bin" | sudo tee -a "/etc/profile"

    # Installing go-task
    sudo sh -c "$(curl --location https://taskfile.dev/install.sh)" -- -d -b /usr/local/bin

    # Installing Kubectl
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/${ARCH}/kubectl"
    sudo mv kubectl /usr/local/bin/kubectl
    sudo chmod +x /usr/local/bin/kubectl

    # Installing Flux CLI
    curl -s https://fluxcd.io/install.sh | sudo bash

    # Git config
    # https://andrei-calazans.com/posts/2021-06-23/passing-secrets-github-actions-docker
    export GIT_USERNAME=$(sudo cat /run/secrets/USERNAME)
    export GIT_MAILADDRESS=$(sudo cat /run/secrets/MAILADDRESS)
    git config --global --add pull.rebase false
    git config --global --add user.name $GIT_USERNAME
    git config --global --add user.email $GIT_MAILADDRESS
    git config --global init.defaultBranch main
    git config --global alias.pullall '!git pull && git submodule update --init --recursive'

    # Adding github.com SSH keys to known_hosts
    curl --silent https://api.github.com/meta \
      | jq --raw-output '"github.com "+.ssh_keys[]' >> ${CODER_HOME}/.ssh/known_hosts

    # Installing vscode plugins
    HOME=${CODER_HOME} code-server \
        --install-extension equinusocio.vsc-material-theme \
        --install-extension PKief.material-icon-theme \
        --install-extension Rubymaniac.vscode-paste-and-indent \
        --install-extension redhat.vscode-yaml \
        --install-extension esbenp.prettier-vscode \
        --install-extension signageos.signageos-vscode-sops \
        --install-extension MichaelCurrin.auto-commit-msg \
        --install-extension hashicorp.terraform \
        --install-extension weaveworks.vscode-gitops-tools

    # Cleaning up
    echo "[code-server] Dependency installation completed, cleaning up..."
    sudo sudo apt remove -y --auto-remove software-properties-common
    rm -rfv /home/coder/*.deb /tmp/*.deb || true
    sudo apt clean
    sudo rm -rvf /var/lib/apt/lists/* /var/cache/debconf/* /tmp/* /var/tmp/*
    rm -f *.vsix && rm -rf ${CODER_HOME}/.local/share/code-server/CachedExtensionVSIXs
    echo "[code-server] Cleanup done"

EOF

COPY --chown=coder:coder config/code-server/settings.json ${CODER_HOME}/.local/share/code-server/User/settings.json
# COPY --chown=coder:coder config/code-server/coder.json ${CODER_HOME}/.local/share/code-server/coder.json
COPY --chown=coder:coder config/mc/ini ${CODER_HOME}/.config/mc/ini
COPY --chown=coder:coder scripts/clone_git_repos.sh ${CODER_HOME}/entrypoint.d/clone_git_repos.sh
COPY --chown=coder:coder --chmod=600 config/ssh/config ${CODER_HOME}/.ssh/config

#WORKDIR ${HOME}/projects

VOLUME $CODER_HOME/projects
VOLUME $CODER_HOME/.ssh

# Executing in shell to invoke variable substitution
ENTRYPOINT /usr/bin/entrypoint.sh \
            --bind-addr 0.0.0.0:8080 \
            --disable-telemetry \
            ${DEFAULT_WORKSPACE}
