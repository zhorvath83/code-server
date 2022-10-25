FROM codercom/code-server:4.8.0 AS code-server

ENV CODER_HOME="/home/coder"

# renovate: datasource=github-releases depName=mikefarah/yq
ENV YQ_VERSION=v4.28.2

# renovate: datasource=github-releases depName=mozilla/sops
ENV SOPS_VERSION=v3.7.3

# code-server uses the Open-VSX extension gallery( https://open-vsx.org/ )
# https://github.com/coder/code-server/blob/main/docs/FAQ.md#how-do-i-use-my-own-extensions-marketplace
ENV EXTENSIONS_GALLERY='{"serviceUrl": "https://marketplace.visualstudio.com/_apis/public/gallery","cacheUrl": "https://vscode.blob.core.windows.net/gallery/index","itemUrl": "https://marketplace.visualstudio.com/items"}'

USER root

RUN apt-get update -y && \
    apt-get install --assume-yes --no-install-recommends \
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
        apache2-utils && \
    ## Homebrew
    # NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" && \
    # echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> /root/.profile && \
    # eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)" && \
    # brew install gcc sops FairwindsOps/tap/pluto && \
    ## Terraform repo
    curl -fsSL https://apt.releases.hashicorp.com/gpg | apt-key add - && \
    apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"  && \
    ## Node.js repo
    curl -sL https://deb.nodesource.com/setup_16.x | bash - && \
    apt-get update -y && \
    ## Terraform, Node.js
    apt-get install -y --no-install-recommends terraform nodejs && \
    apt-get clean && \
    ## Prettier
    npm install --save-dev --save-exact prettier && \
    npm install --global prettier && \
    ## pip
    pip3 install --upgrade pip && \
    ## pre-commit, pre-commit-hooks, yamllint, ansible-core
    pip install pre-commit pre-commit-hooks python-Levenshtein yamllint ansible-core && \
    ## SOPS
    wget -q "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64" -O /usr/bin/yq && \
    chmod +x /usr/bin/yq && \
    wget -q "https://github.com/mozilla/sops/releases/download/${SOPS_VERSION}/sops-${SOPS_VERSION}.linux" -O /usr/local/bin/sops && \
    chmod +x /usr/local/bin/sops && \
    ## Golang
    wget -q -O go.tgz "https://go.dev/dl/$(curl https://go.dev/VERSION?m=text).linux-amd64.tar.gz" && \
    tar -C /usr/local -xzf go.tgz && \
    rm go.tgz && \
    echo 'export PATH=$PATH:/usr/local/go/bin' >> /etc/profile && \
    ## go-task
    sh -c "$(curl --location https://taskfile.dev/install.sh)" -- -d -b /usr/local/bin && \
    apt remove -y --auto-remove software-properties-common && \
    rm -rf /var/lib/apt/lists/*
    #mkdir -p "${CODER_HOME}/.local/share/code-server/extensions" && \
    #chown -R coder:coder "${CODER_HOME}" && \
    #mkdir -p "${CODER_HOME}/.config/mc" && \
    #chown -R coder:coder "${CODER_HOME}/.config/mc" && \
    #curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && \
    #mv kubectl /usr/bin/kubectl && \
    #chmod +x /usr/bin/kubectl && \

USER coder
