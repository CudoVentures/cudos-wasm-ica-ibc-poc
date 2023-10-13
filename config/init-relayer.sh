#!/bin/bash -e

set -a
source "./relayer.env"
set +a

cargo install ibc-relayer-cli --version 1.6.0 --bin hermes --locked

CONFIG_FILE="./relayer-config.toml"
MNEMONIC_FILE_0="./chain-a.mnemonic"
MNEMONIC_FILE_1="./chain-b.mnemonic"
ICA_VERSION="{\"version\":\"ics27-1\",\"controller_connection_id\":\"connection-0\",\"host_connection_id\":\"connection-0\",\"address\":\"\",\"encoding\":\"proto3\",\"tx_type\":\"sdk_multi_msg\"}"

echo "Setting up relayer-config.toml"
# chain 1 settings
sed -i '' "1,/id = ''/ s/id = ''/id = '${CHAIN_ID_0}'/g" $CONFIG_FILE
sed -i '' "1,/rpc_addr = ''/ s#rpc_addr = ''#rpc_addr = '${RPC_ADDR_0}'#g" $CONFIG_FILE
sed -i '' "1,/grpc_addr = ''/ s#grpc_addr = ''#grpc_addr = '${GRPC_ADDR_0}'#g" $CONFIG_FILE
sed -i '' "1,/event_source = ''/ s#event_source = ''#event_source = { mode = 'push', url = '${WEBSOCKET_ADDR_0}', batch_delay = '500ms' }#g" $CONFIG_FILE
sed -i '' "1,/key_name = ''/ s/key_name = ''/key_name = '${CHAIN_ID_0}_key'/g" $CONFIG_FILE

# chain 2 settings
sed -i '' "2,/id = ''/ s/id = ''/id = '${CHAIN_ID_1}'/g" $CONFIG_FILE
sed -i '' "2,/rpc_addr = ''/ s#rpc_addr = ''#rpc_addr = '${RPC_ADDR_1}'#g" $CONFIG_FILE
sed -i '' "2,/grpc_addr = ''/ s#grpc_addr = ''#grpc_addr = '${GRPC_ADDR_1}'#g" $CONFIG_FILE
sed -i '' "2,/event_source = ''/ s#event_source = ''#event_source = { mode = 'push', url = '${WEBSOCKET_ADDR_1}', batch_delay = '500ms' }#g" $CONFIG_FILE
sed -i '' "2,/key_name = ''/ s/key_name = ''/key_name = '${CHAIN_ID_1}_key'/g" $CONFIG_FILE

echo "Setting up relayer wallets for each chain"
hermes --config "${CONFIG_FILE}" keys add --key-name "${CHAIN_ID_0}_key" --chain "${CHAIN_ID_0}" --mnemonic-file "${MNEMONIC_FILE_0}" --overwrite
hermes --config "${CONFIG_FILE}" keys add --key-name "${CHAIN_ID_1}_key" --chain "${CHAIN_ID_1}" --mnemonic-file "${MNEMONIC_FILE_1}" --overwrite

echo "Initializing hermes relayer"
sleep 5
hermes --config "${CONFIG_FILE}" create channel \
    --a-chain "${CHAIN_ID_0}" \
    --b-chain "${CHAIN_ID_1}" \
    --a-port "${CHAIN_0_PORT_ADDR}" \
    --b-port "${CHAIN_1_PORT_ADDR}" \
    --new-client-connection \
    --order ordered \
    --channel-version "${ICA_VERSION}" \
    --yes

# start node as daemon (in background)
echo "Starting Hermes relayer"
sleep 5
hermes --config "${CONFIG_FILE}" start &> /dev/null & 
echo "Hermes relayer started in background"
