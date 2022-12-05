FROM codercom/code-server:4.8.2 AS code-server

SHELL ["/bin/bash", "-c"]

USER coder

ENV CODER_HOME="/home/coder"

# renovate: datasource=github-releases depName=mikefarah/yq
ENV YQ_VERSION=v4.28.2

# renovate: datasource=github-releases depName=mozilla/sops
ENV SOPS_VERSION=v3.7.3

ENV NVM_SH_VERSION=v0.39.2

ENV NODEJS_VERSION=19.2.0

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

    ## Download the signing key to a new keyring for HashiCorp Terraform
	# wget -O- https://apt.releases.hashicorp.com/gpg | \
	#	gpg --dearmor | \
	#	sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
	## Adding the official HashiCorp repository

## Node.js
RUN KEYRING=/usr/share/keyrings/hashicorp-archive-keyring.gpg && \
    curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee "$KEYRING" >/dev/null && \
    # Listing signing key
    gpg --no-default-keyring --keyring "$KEYRING" --list-keys  && \
    echo "deb [signed-by=$KEYRING] \
    https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
    sudo tee /etc/apt/sources.list.d/hashicorp.list && \
    ## Installing Node.js for Prettier
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_SH_VERSION}/install.sh >> ${CODER_HOME}/install_nvm.sh && \
    . ${CODER_HOME}/install_nvm.sh && \
    rm -rf ${CODER_HOME}/install_nvm.sh && \
    source ~/.nvm/nvm.sh && \
    nvm install $NODEJS_VERSION && \
    nvm alias default $NODEJS_VERSION && \
    nvm use default && \
    sudo apt-get update -y

## Terraform, prettier, pre-commit, pre-commit-hooks, yamllint, ansible-core
RUN sudo apt-get install -y --no-install-recommends terraform && \
    sudo apt-get clean

## Prettier
RUN npm install --save-dev --save-exact prettier && \
    ##npm install --global prettier && \
    ## pip
    pip3 install --upgrade pip && \
    ## Installing pre-commit, pre-commit-hooks, yamllint, ansible-core
    pip install pre-commit pre-commit-hooks python-Levenshtein yamllint ansible-core

    ## SOPS for encrypting secrets
RUN wget -q "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64" -O /usr/bin/yq && \
    chmod +x /usr/bin/yq && \
    wget -q "https://github.com/mozilla/sops/releases/download/${SOPS_VERSION}/sops-${SOPS_VERSION}.linux" -O /usr/local/bin/sops && \
    chmod +x /usr/local/bin/sops

## Golang for Go-Task
RUN wget -q -O go.tgz "https://go.dev/dl/$(curl https://go.dev/VERSION?m=text).linux-amd64.tar.gz" && \
    tar -C /usr/local -xzf go.tgz && \
    rm go.tgz && \
    echo 'export PATH=$PATH:/usr/local/go/bin' >> /etc/profile && \
    ## go-task
    sh -c "$(curl --location https://taskfile.dev/install.sh)" -- -d -b /usr/local/bin && \
    sudo apt remove -y --auto-remove software-properties-common && \
    rm -rf /var/lib/apt/lists/*


# Kubectl
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && \
    mv kubectl /usr/bin/kubectl && \
    chmod +x /usr/bin/kubectl

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

# git config
RUN GITUSER=${{ secrets.USERNAME }} && \
	GITMAIL=${{ secrets.MAILADDRESS }} && \
	git config --global --add pull.rebase false && \
	git config --global --add user.name ${GITUSER} && \
	git config --global --add user.email ${GITMAIL} && \
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

COPY --chown=coder:coder settings.json ${CODER_HOME}/.local/share/code-server/User/settings.json

# project volume
RUN mkdir ${CODER_HOME}/project
