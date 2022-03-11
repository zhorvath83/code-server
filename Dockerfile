FROM codercom/code-server:4.1.0 AS code-server

ENV CODER_HOME="/home/coder"

# renovate: datasource=github-releases depName=mikefarah/yq
ENV YQ_VERSION=v4.22.1

# renovate: datasource=github-releases depName=mozilla/sops
ENV SOPS_VERSION=v3.7.2

USER root

RUN apt-get update -y && \
    apt-get install -y net-tools iputils-ping wget vim jq gnupg software-properties-common python3 python3-pip mc ca-certificates wget gnupg unzip && \
    pip3 install --upgrade pip && \
    pip install pre-commit && \
    #curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && \
    #mv kubectl /usr/bin/kubectl && \
    #chmod +x /usr/bin/kubectl && \
    wget -q "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64" -O /usr/bin/yq && \
    chmod +x /usr/bin/yq && \
    wget -q "https://github.com/mozilla/sops/releases/download/${SOPS_VERSION}/sops-${SOPS_VERSION}.linux" -O /usr/local/bin/sops && \
    chmod +x /usr/local/bin/sops && \
    #mkdir -p "${CODER_HOME}/.local/share/code-server/extensions" && \
    #chown -R coder:coder "${CODER_HOME}" && \
    #mkdir -p "${CODER_HOME}/.config/mc" && \
    #chown -R coder:coder "${CODER_HOME}/.config/mc" && \
    apt remove -y software-properties-common && \
    rm -rf /var/lib/apt/lists/*

USER coder
