#!/bin/bash -e

# ENV
SETUP_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
CONFIG_DIR=$SETUP_DIR/config
AVG_BLOCK_TIME=8
CONTRACT_PATH=$SETUP_DIR/artifacts/cudos_wasm_ica_ibc_poc.wasm
TEST_BRANCH="cudos-dev-cosmos-v0.47.3"
ROOT_INSTALL_PATH=$SETUP_DIR/tmp
LOG_DIRECTORY=$ROOT_INSTALL_PATH/logs
LOG_FILE=$LOG_DIRECTORY/log.file
NODE_INSTALL_PATH=$ROOT_INSTALL_PATH/node
NODE_ENV=$CONFIG_DIR/node.env
RELAYER_ENV=$CONFIG_DIR/relayer.env
RELAYER_CONFIG=$CONFIG_DIR/relayer-config.toml
TX_FEES="1000000000000000000acudos"

function loading() {
    local message="$1"
    local total_seconds="$2"
    echo -ne "\033[32m$message\033[0m"
    for (( i=0; i<total_seconds; i++ )); do
        echo -n "."
        sleep 1
    done
    echo ""
}

function info() {
    local message="$1"
    echo -ne "\033[34m$message\033[0m"
    echo ""
    sleep $AVG_BLOCK_TIME
}

function error() {
    local message="$1"
    echo -ne "\033[31m$message\033[0m"
    echo ""
}

# Define Contract Interactions
CONTRACT_STATE_QUERY='{"get_contract_state": {}}'
CONTRACT_ICA_BANK_SEND_TX() {
    local amount=$1
    local denom=$2
    local to_address=$3
    echo "{\"ica_bank_send\": {\"amount\": \"$amount\", \"denom\": \"$denom\", \"to_address\":\"$to_address\"}}"
}

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
mkdir $LOG_DIRECTORY
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
clear
info "Storing contract on $CHAIN_A_ID"
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
    --yes >> $LOG_FILE

info "Instantiating contract on $CHAIN_A_ID"
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
    --yes >> $LOG_FILE

# Setting up Relayer
info "Initiating Relayer"
result=($(echo "$(cudos-noded q wasm list-contracts-by-creator \
    $INSTANTIATOR_ADDR \
    --node=$CHAIN_A_NODE)" | tr ',' '\n'))
CONTRACT_ADDRESS=$(echo "${result[2]}")
CHAIN_A_RELAYER_PORT=$(echo "wasm.${CONTRACT_ADDRESS}")
sed -i '' 's|CHAIN_ID_0=""|CHAIN_ID_0='\""${CHAIN_A_ID}\""'|g' $RELAYER_ENV
sed -i '' 's|CHAIN_0_PORT_ADDR=""|CHAIN_0_PORT_ADDR='\""${CHAIN_A_RELAYER_PORT}\""'|g' $RELAYER_ENV
sed -i '' 's|CHAIN_ID_1=""|CHAIN_ID_1='\""${CHAIN_B_ID}\""'|g' $RELAYER_ENV

cd $CONFIG_DIR
chmod +x ./init-relayer.sh
./init-relayer.sh

info "Getting ICA address"
raw_output=$(cudos-noded q wasm contract-state smart \
    "$CONTRACT_ADDRESS" \
    "$CONTRACT_STATE_QUERY" \
    --home=$CHAIN_A_HOME \
    --node="$CHAIN_A_NODE")
ICA_ADDRESS=$(echo "$raw_output" | awk -F': ' '/ica_address/ {print $2}')
echo $ICA_ADDRESS > "${CONFIG_DIR}/ica.address"

CHAIN_B_FUNDS_HOLDER_ADDR=$(cudos-noded keys show test-admin -a --keyring-backend=test --home=$CHAIN_B_HOME)
FUND_AMOUNT="100000000000000000000acudos"
loading "Funding ICA Address: $ICA_ADDRESS with $FUND_AMOUNT on $CHAIN_B_ID" 3
cudos-noded tx bank send \
    "$CHAIN_B_FUNDS_HOLDER_ADDR" \
     "$ICA_ADDRESS" \
     "$FUND_AMOUNT" \
    --node=$CHAIN_B_NODE \
    --home=$CHAIN_B_HOME \
    --chain-id=$CHAIN_B_ID \
    --from=test-admin \
    --keyring-backend=test \
     --fees=$TX_FEES \
     --yes >> $LOG_FILE

loading "Querying ICA Address balance on: $CHAIN_B_ID" 3
cudos-noded q bank balances \
     "$ICA_ADDRESS" \
    --node=$CHAIN_B_NODE \
    --home=$CHAIN_B_HOME

NEW_ACCOUNT_NAME="test-account"
loading "Creating new account on: $CHAIN_B_ID named: ${NEW_ACCOUNT_NAME}" 3
cudos-noded keys add \
    "$NEW_ACCOUNT_NAME" \
    --home=$CHAIN_B_HOME \
    --keyring-backend=test > $ROOT_INSTALL_PATH/$NEW_ACCOUNT_NAME.account
NEW_ACCOUNT_ADDR=$(cudos-noded keys show $NEW_ACCOUNT_NAME -a --keyring-backend=test --home=$CHAIN_B_HOME)
info "Account created: $NEW_ACCOUNT_ADDR"

loading "Verifying $NEW_ACCOUNT_NAME:$NEW_ACCOUNT_ADDR have empty balance on: $CHAIN_B_ID" 3
cudos-noded q bank balances \
     "$NEW_ACCOUNT_ADDR" \
    --node=$CHAIN_B_NODE \
    --home=$CHAIN_B_HOME

AMOUNT_TO_SEND="100"
DENOM_TO_SEND="acudos"
info "Trigerring IBC/ICA interaction by sending $AMOUNT_TO_SEND$DENOM_TO_SEND to $NEW_ACCOUNT_ADDR on $$CHAIN_B_ID"
cudos-noded tx wasm execute \
    "$CONTRACT_ADDRESS" \
     "$(CONTRACT_ICA_BANK_SEND_TX "$AMOUNT_TO_SEND" "$DENOM_TO_SEND" "$NEW_ACCOUNT_ADDR")" \
    --node=$CHAIN_A_NODE \
    --home=$CHAIN_A_HOME \
    --chain-id=$CHAIN_A_ID \
    --from=test-admin \
    --keyring-backend=test \
    --fees=$TX_FEES \
    --yes >> $LOG_FILE

RETRIES=0
MAX_RETRIES=3
SUCCESS=false
HERMES_PID=$CONFIG_DIR/hermes.pid
HERMES_CONFIG="$CONFIG_DIR/relayer-config.toml"
while [[ $RETRIES -lt $MAX_RETRIES && $SUCCESS == false ]]; do
    loading "Checking $NEW_ACCOUNT_NAME:$NEW_ACCOUNT_ADDR new balance on: $CHAIN_B_ID" $(($AVG_BLOCK_TIME * $MAX_RETRIES))
    balance_output=$(cudos-noded q bank balances "$NEW_ACCOUNT_ADDR" --node=$CHAIN_B_NODE --home=$CHAIN_B_HOME)
    if echo "$balance_output" | grep "balances:" | awk '{print $2}' | grep -q '^\[\]$'; then
        error "$NEW_ACCOUNT_ADDR balance is empty"
        info "Restarting Hermes Relayer and retrying"        
        kill $(cat $HERMES_PID)
        hermes --config "${HERMES_CONFIG}" start &> /dev/null &
        echo $! > $HERMES_PID
        info "Relayer restarted"
        RETRIES=$((RETRIES + 1))
    else
        loading "SUCCESS" 0
        echo "$NEW_ACCOUNT_NAME:$NEW_ACCOUNT_ADDR updated balances on: $CHAIN_B_ID"
        echo "$balance_output"
        exit 0
    fi
done
error "Failed to complete the tests after $MAX_RETRIES attempts."
exit 1
