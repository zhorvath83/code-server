FROM codercom/code-server:4.1.0 AS code-server

ENV CODER_HOME=/home/coder

# renovate: datasource=github-releases depName=mikefarah/yq
ENV YQ_VERSION=v4.21.1

# renovate: datasource=github-releases depName=mozilla/sops
ENV SOPS_VERSION=v3.7.2

RUN sudo apt-get update -y && \
    sudo apt-get install -y net-tools iputils-ping wget vim jq gnupg software-properties-common python3 python3-pip mc ca-certificates wget gnupg unzip && \
    sudo pip3 install --upgrade pip && \
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && \
    sudo mv kubectl /usr/bin/kubectl && \
    sudo chmod +x /usr/bin/kubectl && \
    sudo wget -q "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/linux_amd64" -O /usr/bin/yq && \
    sudo chmod +x /usr/bin/yq && \
    wget -q https://github.com/mozilla/sops/releases/download/${SOPS_VERSION}/sops-${SOPS_VERSION}.linux -O /usr/local/bin/sops && \
    chmod +x /usr/local/bin/sops
    sudo mkdir -p "${CODER_HOME}/.local/share/code-server/extensions" && \
    sudo chown -R coder:coder "${CODER_HOME}" && \
    sudo mkdir -p "${CODER_HOME}/.config/mc" && \
    sudo chown -R coder:coder "${CODER_HOME}/.config/mc" && \
    sudo apt remove -y software-properties-common && \
    sudo rm -rf /var/lib/apt/lists/*
