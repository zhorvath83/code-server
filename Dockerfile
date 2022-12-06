FROM codercom/code-server:4.8.2 AS code-server

SHELL ["/bin/bash", "-c"]

USER coder

ARG ARCH=amd64
ARG CODER_HOME="/home/coder"

# renovate: datasource=github-releases depName=mikefarah/yq
ARG YQ_VERSION=v4.28.2

# renovate: datasource=github-releases depName=mozilla/sops
ARG SOPS_VERSION=v3.7.3

# renovate: datasource=golang-version
ARG GO_VERSION=1.19.4

# code-server uses the Open-VSX extension gallery( https://open-vsx.org/ )
# https://github.com/coder/code-server/blob/main/docs/FAQ.md#how-do-i-use-my-own-extensions-marketplace
ENV EXTENSIONS_GALLERY='{"serviceUrl": "https://marketplace.visualstudio.com/_apis/public/gallery","cacheUrl": "https://vscode.blob.core.windows.net/gallery/index","itemUrl": "https://marketplace.visualstudio.com/items"}'

RUN sudo apt-get update -y && \
    sudo apt-get install --assume-yes --no-install-recommends \
        net-tools \
        iputils-ping \
        wget \
        vim \
        jq \
        gnupg \
        software-properties-common \
        python3 \
        python3-pip \
        build-essential \
        python3-dev \
        mc \
        ca-certificates \
        unzip \
        bzr \
        curl \
        git-extras \
        # For generating htpasswd
        apache2-utils

# zsh
RUN curl -o- https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh >> ~/oh_my_zsh.sh && \
    echo 'y' | . ~/oh_my_zsh.sh && \
    rm -rf  ~/oh_my_zsh.sh && \
    git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions && \
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting && \
    sed -i "s/plugins=(git.*)$/plugins=(git zsh-syntax-highlighting zsh-autosuggestions)/" ~/.zshrc 

# default bash
RUN echo "dash dash/sh boolean false" | sudo debconf-set-selections && \
    sudo DEBIAN_FRONTEND=noninteractive dpkg-reconfigure dash

# Adding Hashicorp and Node.js repo
# Installing Terraform and npm (for Prettier)
RUN KEYRING=/usr/share/keyrings/hashicorp-archive-keyring.gpg && \
    curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee "$KEYRING" >/dev/null && \
    # Listing signing key
    gpg --no-default-keyring --keyring "$KEYRING" --list-keys && \
    echo "deb [signed-by=$KEYRING] \
    https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
    sudo tee /etc/apt/sources.list.d/hashicorp.list && \
    # Node.js repo
    curl -fsSL https://deb.nodesource.com/setup_19.x | sudo -E bash - &&\
    # Terraform and nodejs
    sudo apt-get update -y &&\
    sudo apt-get install -y --no-install-recommends terraform nodejs && \
    sudo apt-get clean

# Installing Terraform, prettier, pre-commit, pre-commit-hooks, yamllint, ansible-core
RUN sudo npm install --save-dev --save-exact prettier && \
    ##npm install --global prettier && \
    # pip
    sudo pip3 install --upgrade pip && \
    # Installing pre-commit, pre-commit-hooks, yamllint, ansible-core && \
    sudo pip install pre-commit pre-commit-hooks python-Levenshtein yamllint ansible-core


# Installing SOPS for encrypting secrets
RUN sudo wget -q "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64" -O /usr/bin/yq && \
    sudo chmod +x /usr/bin/yq && \
    sudo wget -q "https://github.com/mozilla/sops/releases/download/${SOPS_VERSION}/sops-${SOPS_VERSION}.linux" -O /usr/local/bin/sops && \
    sudo chmod +x /usr/local/bin/sops

# Golang for Go-Task
ARG GOPATH=$HOME/go
ENV PATH=$PATH:/usr/local/go/bin
RUN export GOPKG="go${GO_VERSION}.linux-${ARCH}.tar.gz"; \
    wget "https://golang.org/dl/${GOPKG}" && \
    sudo tar -C /usr/local -xzf "${GOPKG}" && \
    mkdir -p "${GOPATH}" && \
    rm "${GOPKG}" && \
    go version && \
    # Updating all packages in GOPATH
    go get -u all && \
    go mod tidy && \
    echo "export GOPATH=$GOPATH" >> ~/.profile && \
    echo "export PATH=$GOPATH/bin:$PATH" >> ~/.profile && \
    echo "export PATH=$PATH:/usr/local/go/bin" >> ~/.profile && \
    echo "export PATH=$PATH:/usr/local/go/bin" >> /etc/profile

# Installing go-task
RUN sudo sh -c "$(curl --location https://taskfile.dev/install.sh)" -- -d -b /usr/local/bin

# Kubectl
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && \
    sudo mv kubectl /usr/bin/kubectl && \
    sudo chmod +x /usr/bin/kubectl

# Git config
# https://andrei-calazans.com/posts/2021-06-23/passing-secrets-github-actions-docker
RUN --mount=type=secret,id=USERNAME \
    --mount=type=secret,id=MAILADDRESS \
    export GIT_USERNAME=$(sudo cat /run/secrets/USERNAME) && \
    export GIT_MAILADDRESS=$(sudo cat /run/secrets/MAILADDRESS) && \
    git config --global --add pull.rebase false && \
    git config --global --add user.name $GIT_USERNAME && \
    git config --global --add user.email $GIT_MAILADDRESS && \
    git config --global core.editor vim && \
    git config --global init.defaultBranch master && \
    git config --global alias.pullall '!git pull && git submodule update --init --recursive'

# vscode plugin
RUN HOME=${CODER_HOME} code-server \
	--user-data-dir=${CODER_HOME}/.local/share/code-server \
	--install-extension equinusocio.vsc-material-theme \
	--install-extension PKief.material-icon-theme \
	--install-extension vscode-icons-team.vscode-icons \
    	--install-extension Rubymaniac.vscode-paste-and-indent \
    	--install-extension redhat.vscode-yaml \
    	--install-extension esbenp.prettier-vscode \
    	--install-extension signageos.signageos-vscode-sops \
    	--install-extension MichaelCurrin.auto-commit-msg

# Cleanup
RUN sudo sudo apt remove -y --auto-remove software-properties-common && \
    sudo rm -rf /var/lib/apt/lists/*

COPY --chown=coder:coder settings.json ${CODER_HOME}/.local/share/code-server/User/settings.json

# project volume
RUN mkdir ${CODER_HOME}/project
