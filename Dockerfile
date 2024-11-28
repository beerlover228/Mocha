FROM ubuntu:latest

RUN apt-get update && \
apt-get upgrade -y && \
apt-get install curl tar wget clang pkg-config libssl-dev jq build-essential bsdmainutils git make ncdu gcc git jq chrony liblz4-tool -yt -y

ENV HOME=/app
WORKDIR /app

ENV GO_VER="1.23.2"
ENV PATH="/usr/local/go/bin:/app/go/bin:${PATH}"
ENV SEEDS=$(curl -sL https://raw.githubusercontent.com/celestiaorg/networks/master/mocha-4/seeds.txt | tr '\n' ',')
ENV RPC="https://celestia.rpc.t.stavr.tech:443"
ENV LATEST_HEIGHT=$(curl -s $RPC/block | jq -r .result.block.header.height)
ENV BLOCK_HEIGHT=$((LATEST_HEIGHT - 1000))
ENV TRUST_HASH=$(curl -s "$RPC/block?height=$BLOCK_HEIGHT" | jq -r .result.block_id.hash)

RUN wget "https://golang.org/dl/go$GO_VER.linux-amd64.tar.gz" && \
tar -C /usr/local -xzf "go$GO_VER.linux-amd64.tar.gz" && \
rm "go$GO_VER.linux-amd64.tar.gz" && \
mkdir -p go/bin

RUN git clone https://github.com/celestiaorg/celestia-app.git && \
cd celestia-app && \
git checkout tags/v3.0.0-mocha && \
make install

RUN celestia-appd init "Stake Shark" --chain-id mocha-4 && \
celestia-appd download-genesis mocha-4


RUN sed -i.bak -e "s/^seeds *=.*/seeds = \"$SEEDS\"/" $HOME/.celestia-app/config/config.toml && \
sed -i -e "s/^pruning *=.*/pruning = \"custom\"/" $HOME/.celestia-app/config/app.toml && \
sed -i -e "s/^pruning-keep-recent *=.*/pruning-keep-recent = \"1000\"/" $HOME/.celestia-app/config/app.toml && \
sed -i -e "s/^pruning-interval *=.*/pruning-interval = \"10\"/" $HOME/.celestia-app/config/app.toml && \
sed -i -e "s/min-retain-blocks *=.*/min-retain-blocks = \"1000\"/" $HOME/.celestia-app/config/app.toml && \
sed -i -e "s/prometheus = false/prometheus = true/" $HOME/.celestia-app/config/config.toml && \
sed -i.bak -e "s/^external_address *=.*/external_address = \"$(wget -qO- eth0.me):26656\"/" $HOME/.celestia-app/config/config.toml && \
sed -i -e "s/^indexer *=.*/indexer = \"null\"/" $HOME/.celestia-app/config/config.toml && \
sed -i 's/max_num_inbound_peers =.*/max_num_inbound_peers = 40/g' $HOME/.celestia-app/config/config.toml && \
sed -i 's/max_num_outbound_peers =.*/max_num_outbound_peers = 10/g' $HOME/.celestia-app/config/config.toml && \
sed -i.bak -E "s|^(enable[[:space:]]+=[[:space:]]+).*$|\1true| ; \
s|^(rpc_servers[[:space:]]+=[[:space:]]+).*$|\1\"$RPC,$RPC\"| ; \
s|^(trust_height[[:space:]]+=[[:space:]]+).*$|\1$BLOCK_HEIGHT| ; \
s|^(trust_hash[[:space:]]+=[[:space:]]+).*$|\1\"$TRUST_HASH\"| ; \
s|^(seeds[[:space:]]+=[[:space:]]+).*$|\1\"\"|" $HOME/.celestia-app/config/config.toml


RUN celestia-appd tendermint unsafe-reset-all --home $HOME/.celestia-app && \
wget -O $HOME/.celestia-app/config/addrbook.json "https://raw.githubusercontent.com/111STAVR111/props/main/Celestia/Testnet/Node/addrbook.json"

RUN snap install lz4 && \
cp $HOME/.celestia-app/data/priv_validator_state.json $HOME/.celestia-app/priv_validator_state.json.backup && \
rm -rf $HOME/.celestia-app/data && \
curl -o - -L https://celestia-t.snapshot.stavr.tech/celestia-t-snap.tar.lz4 | lz4 -c -d - | tar -x -C $HOME/.celestia-app && \
mv $HOME/.celestia-app/priv_validator_state.json.backup $HOME/.celestia-app/data/priv_validator_state.json && \
wget -O $HOME/.celestia-app/config/addrbook.json "https://raw.githubusercontent.com/111STAVR111/props/main/Celestia/Testnet/Node/addrbook.json"


RUN echo '#!/bin/sh' > /app/entrypoint.sh && \
    echo 'sleep 10000' >> /app/entrypoint.sh && \
    chmod +x /app/entrypoint.sh
    
ENTRYPOINT ["/app/entrypoint.sh"]
