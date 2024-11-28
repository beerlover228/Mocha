FROM ubuntu:latest

RUN apt-get update && \
apt-get upgrade -y && \
apt-get install curl git wget htop tmux build-essential jq make lz4 gcc unzip -y

ENV HOME=/app
WORKDIR /app

ENV GO_VER="1.23.2"
ENV PATH="/usr/local/go/bin:/app/go/bin:${PATH}"
ENV WALLET="wallet"
ENV MONIKER="Stake Shark"
ENV CELESTIA_CHAIN_ID="mocha-4"
ENV CELESTIA_PORT="11"
ENV APP_VERSION=v3.0.2-mocha
ENV SEEDS="5d0bf034d6e6a8b5ee31a2f42f753f1107b3a00e@celestia-testnet-seed.itrocket.net:11656"
ENV PEERS="daf2cecee2bd7f1b3bf94839f993f807c6b15fbf@celestia-testnet-peer.itrocket.net:11656,800059f98018b5d05c6b3402071b745fdb2a6d59@85.190.134.38:26656,04d51161e4431b8e5f4d6d8b14655d041b3ea041@51.178.74.112:11056,8811d2ca0ff7078a87bfbbfe7c340c6cb7de616b@164.68.111.29:26656,bdde9be71fa7bb568e09068238cf5db1dc995258@65.109.84.33:11656,6d996aeed0402ce5da57c1272eb33f7b38c183ec@43.157.38.30:26656,6ac4d095a69c2b55c85725e05f9129c9e6b246c8@205.178.182.220:26656,4dfa2dca05dd943ab637a6bb1c9b18d6ea133df2@148.113.16.39:11656,24f79d2f249d491daae85fdc774203c47b2fbcab@91.191.213.10:26656,b977ffaf75faed21a9ac2b758da5ddb0545e9c8e@51.79.19.101:26656,6ed983017167d96c62b166725250940deb783563@65.108.142.147:27656,2c27344691e633115a2d01a2f7ae2117dd30c159@65.108.107.226:23316,14973f993d5418e93e735885abaca693e6c979da@37.27.109.215:26656,2abbf1892ce9d91acbbc55b112f3561b01fc3465@162.62.126.26:26656,f07813ee16dabdeb370c7ffbdbbc73d9f4db48d5@139.45.205.58:28656,6fde8d9cffe2c2fd5c6e4555dde41901a7d63540@65.108.234.28:36656,c758100ed28cbc8bb657352b049b452ddad71247@141.98.217.188:26656,16c5b4463706f49d2db19d3288516efc50582000@65.21.233.188:11656,a831cf42d79aded9d25efd71b1a6629311c2f644@95.217.120.205:11656"

RUN wget "https://golang.org/dl/go$GO_VER.linux-amd64.tar.gz" && \
tar -C /usr/local -xzf "go$GO_VER.linux-amd64.tar.gz" && \
rm "go$GO_VER.linux-amd64.tar.gz" && \
mkdir -p go/bin

RUN git clone https://github.com/celestiaorg/celestia-app.git && \
cd celestia-app/ && \
git checkout tags/$APP_VERSION -b $APP_VERSION && \
make install

RUN celestia-appd config node tcp://localhost:${CELESTIA_PORT}657 && \
celestia-appd config keyring-backend os && \
celestia-appd config chain-id mocha-4 && \
celestia-appd init "Stake Shark" --chain-id mocha-4 && \
celestia-appd download-genesis mocha-4

RUN wget -O $HOME/.celestia-app/config/addrbook.json  https://server-4.itrocket.net/testnet/celestia/addrbook.json

RUN sed -i -e "/^\[p2p\]/,/^\[/{s/^[[:space:]]*seeds *=.*/seeds = \"$SEEDS\"/}" \
       -e "/^\[p2p\]/,/^\[/{s/^[[:space:]]*persistent_peers *=.*/persistent_peers = \"$PEERS\"/}" $HOME/.celestia-app/config/config.toml && \
sed -i.bak -e "s%:1317%:${CELESTIA_PORT}317%g; \
s%:8080%:${CELESTIA_PORT}080%g; \
s%:9090%:${CELESTIA_PORT}090%g; \
s%:9091%:${CELESTIA_PORT}091%g; \
s%:8545%:${CELESTIA_PORT}545%g; \
s%:8546%:${CELESTIA_PORT}546%g; \
s%:6065%:${CELESTIA_PORT}065%g" $HOME/.celestia-app/config/app.toml && \
sed -i.bak -e "s%:26658%:${CELESTIA_PORT}658%g; \
s%:26657%:${CELESTIA_PORT}657%g; \
s%:6060%:${CELESTIA_PORT}060%g; \
s%:26656%:${CELESTIA_PORT}656%g; \
s%^external_address = \"\"%external_address = \"$(wget -qO- eth0.me):${CELESTIA_PORT}656\"%; \
s%:26660%:${CELESTIA_PORT}660%g" $HOME/.celestia-app/config/config.toml && \
sed -i -e "s/^pruning *=.*/pruning = \"custom\"/" $HOME/.celestia-app/config/app.toml && \
sed -i -e "s/^pruning-keep-recent *=.*/pruning-keep-recent = \"1000\"/" $HOME/.celestia-app/config/app.toml && \
sed -i -e "s/^pruning-interval *=.*/pruning-interval = \"10\"/" $HOME/.celestia-app/config/app.toml && \
sed -i 's|minimum-gas-prices =.*|minimum-gas-prices = "0.002utia"|g' $HOME/.celestia-app/config/app.toml && \
sed -i -e "s/prometheus = false/prometheus = true/" $HOME/.celestia-app/config/config.toml && \
sed -i -e "s/^indexer *=.*/indexer = \"null\"/" $HOME/.celestia-app/config/config.toml && \
sed -i 's/max_num_inbound_peers =.*/max_num_inbound_peers = 40/g' $HOME/.celestia-app/config/config.toml && \
sed -i 's/max_num_outbound_peers =.*/max_num_outbound_peers = 10/g' $HOME/.celestia-app/config/config.toml


RUN echo '#!/bin/sh' > /app/entrypoint.sh && \
    echo 'sleep 10000' >> /app/entrypoint.sh && \
    chmod +x /app/entrypoint.sh
    
ENTRYPOINT ["/app/entrypoint.sh"]
