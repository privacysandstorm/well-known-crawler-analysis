FROM debian:latest as base
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y curl \
    git \
    jq \
    unzip \
    wget \
    zstd && \
    apt-get clean autoclean && \
    apt-get autoremove

RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install

# For VScode development purposes
FROM base AS vscode_dev
RUN addgroup --gid 1000 vscode
RUN adduser --disabled-password --gecos "" --uid 1000 --gid 1000 vscode
ENV HOME /home/vscode
USER vscode

# For analysis
FROM base as analysis
WORKDIR /analysis
COPY ./ /analysis
ENTRYPOINT ["./analysis.sh"]