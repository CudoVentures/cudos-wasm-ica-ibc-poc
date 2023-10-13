#!/bin/bash -e

# ENV
SETUP_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
CONFIG_DIR=$SETUP_DIR/config
AVG_BLOCK_TIME=8
SUPRESS_OUTPUT=/dev/null 2>&1
CONTRACT_PATH=$SETUP_DIR/artifacts/cudos_wasm_ica_ibc_poc.wasm
TEST_BRANCH="cudos-dev-cosmos-v0.47.3"
ROOT_INSTALL_PATH=$SETUP_DIR/tmp
NODE_INSTALL_PATH=$ROOT_INSTALL_PATH/node
NODE_ENV=$CONFIG_DIR/node.env
RELAYER_ENV=$CONFIG_DIR/relayer.env
RELAYER_CONFIG=$CONFIG_DIR/relayer-config.toml

# Define Contract Interactions
CONTRACT_STATE_QUERY='{"get_contract_state": {}}'

# COMPILE CONTRACT
cargo clean && cargo build
docker run --rm -v "$(pwd)":/code \
  --mount type=volume,source="$(basename "$(pwd)")_cache",target=/code/target \
  --mount type=volume,source=registry_cache,target=/usr/local/cargo/registry \
  cosmwasm/rust-optimizer:0.12.13

# CLEAN UP from previous run
rm -rf $ROOT_INSTALL_PATH
rm -rf $RELAYER_ENV
rm -rf $RELAYER_CONFIG
rm -rf $NODE_ENV
mkdir $ROOT_INSTALL_PATH
cp $RELAYER_ENV.example $RELAYER_ENV
cp $RELAYER_CONFIG.example $RELAYER_CONFIG
cp $NODE_ENV.example $NODE_ENV

# SET UP A & B CHAINS
git clone -b $TEST_BRANCH https://github.com/CudoVentures/cudos-node.git $NODE_INSTALL_PATH
cp "$SETUP_DIR/config/init-chain.sh" $NODE_INSTALL_PATH/
cp "$SETUP_DIR/config/node.env" $NODE_INSTALL_PATH/
cd $NODE_INSTALL_PATH
make install

# CHAIN A
CHAIN_A_RPC_PORT="26657"
CHAIN_A_ID="a-chain"
CHAIN_A_HOME=$NODE_INSTALL_PATH/cudos-${CHAIN_A_ID}-data
CHAIN_A_NODE="http://localhost:$CHAIN_A_RPC_PORT"
lsof -i :$CHAIN_A_RPC_PORT| grep LISTEN | awk '{print $2}' | xargs kill -9
./init-chain.sh $CHAIN_A_ID $CHAIN_A_RPC_PORT
cp -r $CHAIN_A_HOME/test-admin.wallet $CONFIG_DIR/chain-a.mnemonic

# CHAIN B
CHAIN_B_RPC_PORT="26654"
CHAIN_B_ID="b-chain"
CHAIN_B_HOME=$NODE_INSTALL_PATH/cudos-${CHAIN_B_ID}-data
CHAIN_B_NODE="http://localhost:$CHAIN_B_RPC_PORT"
lsof -i :$CHAIN_B_RPC_PORT| grep LISTEN | awk '{print $2}' | xargs kill -9
./init-chain.sh $CHAIN_B_ID $CHAIN_B_RPC_PORT
cp -r $CHAIN_B_HOME/test-admin.wallet $CONFIG_DIR/chain-b.mnemonic

# SET UP CONTRACT ON CHAIN A as ICA controller
echo "Storing contract on $CHAIN_A_ID"
sleep $AVG_BLOCK_TIME
cudos-noded tx wasm store \
    $CONTRACT_PATH \
    --node=$CHAIN_A_NODE \
    --home=$CHAIN_A_HOME \
    --chain-id=$CHAIN_A_ID \
    --from=test-admin \
    --keyring-backend=test \
    --gas-prices=5000000000000acudos \
    --gas=8000000 \
    --gas-adjustment=1.3 \
    --yes > $SUPRESS_OUTPUT
sleep $AVG_BLOCK_TIME

echo "Instantiating contract on $CHAIN_A_ID"
INSTANTIATOR_ADDR=$(cudos-noded keys show test-admin -a --keyring-backend=test --home=$CHAIN_A_HOME)
cudos-noded tx wasm instantiate 1 '{}' \
    --node=$CHAIN_A_NODE \
    --home=$CHAIN_A_HOME \
    --chain-id=$CHAIN_A_ID \
    --from=$INSTANTIATOR_ADDR \
    --keyring-backend=test \
    --gas-prices=5000000000000acudos \
    --gas=8000000 \
    --gas-adjustment=1.3 \
    --label="test" \
    --no-admin \
    --yes > $SUPRESS_OUTPUT
sleep $AVG_BLOCK_TIME

# Extract and save the contract address / ICA Port
result=($(echo "$(cudos-noded q wasm list-contracts-by-creator \
    $INSTANTIATOR_ADDR \
    --node=$CHAIN_A_NODE)" | tr ',' '\n'))
CONTRACT_ADDRESS=$(echo "${result[2]}")
CHAIN_A_RELAYER_PORT=$(echo "wasm.${CONTRACT_ADDRESS}")

# Setting up Relayer
echo "Editting Relayer env"
sed -i '' 's|CHAIN_ID_0=""|CHAIN_ID_0='\""${CHAIN_A_ID}\""'|g' $RELAYER_ENV
sed -i '' 's|CHAIN_0_PORT_ADDR=""|CHAIN_0_PORT_ADDR='\""${CHAIN_A_RELAYER_PORT}\""'|g' $RELAYER_ENV
sed -i '' 's|CHAIN_ID_1=""|CHAIN_ID_1='\""${CHAIN_B_ID}\""'|g' $RELAYER_ENV

cd $CONFIG_DIR
echo "Initiating Relayer"
chmod +x ./init-relayer.sh
./init-relayer.sh

echo "Getting ICA address"
raw_output=$(cudos-noded q wasm contract-state smart \
    "$CONTRACT_ADDRESS" \
    "$CONTRACT_STATE_QUERY" \
    --node="$CHAIN_A_NODE")
ICA_ADDRESS=$(echo "$raw_output" | awk -F': ' '/ica_address/ {print $2}')
echo $ICA_ADDRESS > "${CONFIG_DIR}/ica.address"

