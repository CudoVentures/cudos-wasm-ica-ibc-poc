#!/bin/bash -e

set -a
source ./node.env
set +a

if [ -z "$1" ]; then
    echo "Invalid CHAIN-ID"
    exit 1
fi

SED_IN_PLACE="sed -i"
if [[ "$OSTYPE" == "darwin"* ]]; then
    SED_IN_PLACE="sed -i ''"
fi

MONIKER="$1"
CHAIN_ID="$1"
CUDOS_HOME="./cudos-${CHAIN_ID}-data"

rm -rf $CUDOS_HOME
mkdir $CUDOS_HOME

VALID_TOKEN_CONTRACT_ADDRESS="false"
if [ "$CUDOS_TOKEN_CONTRACT_ADDRESS" = "0xE92f6A5b005B8f98F30313463Ada5cb35500a919" ] || [ "$CUDOS_TOKEN_CONTRACT_ADDRESS" = "0x12d474723cb8c02bcbf46cd335a3bb4c75e9de44" ]; then
  VALID_TOKEN_CONTRACT_ADDRESS="true"
  PARAM_UNBONDING_TIME="28800s"
  PARAM_MAX_DEPOSIT_PERIOD="21600s"
  PARAM_VOTING_PERIOD="21600s"
fi
if [ "$CUDOS_TOKEN_CONTRACT_ADDRESS" = "0x817bbDbC3e8A1204f3691d14bB44992841e3dB35" ]; then
  VALID_TOKEN_CONTRACT_ADDRESS="true"
  PARAM_UNBONDING_TIME="1814400s"
  PARAM_MAX_DEPOSIT_PERIOD="1209600s"
  PARAM_VOTING_PERIOD="432000s"
fi
if [ "$VALID_TOKEN_CONTRACT_ADDRESS" = "false" ]; then
  echo "Wrong contract address"
  exit 0;
fi;

BOND_DENOM="acudos"

cudos-noded init $MONIKER --chain-id=$CHAIN_ID  --home=$CUDOS_HOME

# gas price
$SED_IN_PLACE "s/minimum-gas-prices = \"\"/minimum-gas-prices = \"5000000000000${BOND_DENOM}\"/" "${CUDOS_HOME}/config/app.toml"

# port 1317
# enable
$SED_IN_PLACE "/\[api\]/,/\[/ s/enable = false/enable = true/" "${CUDOS_HOME}/config/app.toml"
$SED_IN_PLACE "s/enabled-unsafe-cors = false/enabled-unsafe-cors = true/" "${CUDOS_HOME}/config/app.toml"

# port 9090
# enable
$SED_IN_PLACE "/\[grpc\]/,/\[/ s/enable = false/enable = true/" "${CUDOS_HOME}/config/app.toml"

# port 26657
# enable
$SED_IN_PLACE "s/laddr = \"tcp:\/\/127.0.0.1:26657\"/laddr = \"tcp:\/\/0.0.0.0:26657\"/" "${CUDOS_HOME}/config/config.toml"
$SED_IN_PLACE "s/cors_allowed_origins = \[\]/cors_allowed_origins = \[\"\*\"\]/" "${CUDOS_HOME}/config/config.toml"

# port 26660
if [ "${MONITORING_ENABLED}" = "true" ]; then
    $SED_IN_PLACE "s/prometheus = .*/prometheus = true/g" "${CUDOS_HOME}/config/config.toml"
fi
if [ "${MONITORING_ENABLED}" = "false" ]; then
    $SED_IN_PLACE "s/prometheus = .*/prometheus = false/g" "${CUDOS_HOME}/config/config.toml"
fi

$SED_IN_PLACE "s/pex = true/pex = false/" "${CUDOS_HOME}/config/config.toml"

if [ "${ADDR_BOOK_STRICT}" = "false" ]; then
    $SED_IN_PLACE "s/addr_book_strict = true/addr_book_strict = false/g" "${CUDOS_HOME}/config/config.toml"
fi

MY_OWN_PEER_ID=$(cudos-noded tendermint show-node-id --home=$CUDOS_HOME)
$SED_IN_PLACE "s/private_peer_ids = \"\"/private_peer_ids = \"$MY_OWN_PEER_ID\"/g" "${CUDOS_HOME}/config/config.toml"

# consensus params
genesisJson=$(jq ".consensus_params.evidence.max_age_num_blocks = \"531692\"" "${CUDOS_HOME}/config/genesis.json")
echo $genesisJson > "${CUDOS_HOME}/config/genesis.json"

# slashing params
genesisJson=$(jq ".app_state.slashing.params.signed_blocks_window = \"19200\"" "${CUDOS_HOME}/config/genesis.json")
echo $genesisJson > "${CUDOS_HOME}/config/genesis.json"
genesisJson=$(jq ".app_state.slashing.params.min_signed_per_window = \"0.1\"" "${CUDOS_HOME}/config/genesis.json")
echo $genesisJson > "${CUDOS_HOME}/config/genesis.json"
genesisJson=$(jq ".app_state.slashing.params.slash_fraction_downtime = \"0.0001\"" "${CUDOS_HOME}/config/genesis.json")
echo $genesisJson > "${CUDOS_HOME}/config/genesis.json"

# staking params
genesisJson=$(jq ".app_state.staking.params.bond_denom = \"$BOND_DENOM\"" "${CUDOS_HOME}/config/genesis.json")
echo $genesisJson > "${CUDOS_HOME}/config/genesis.json"
genesisJson=$(jq ".app_state.staking.params.unbonding_time = \"$PARAM_UNBONDING_TIME\"" "${CUDOS_HOME}/config/genesis.json")
echo $genesisJson > "${CUDOS_HOME}/config/genesis.json"

# crisis params
genesisJson=$(jq ".app_state.crisis.constant_fee.amount = \"5000000000000000000000\"" "${CUDOS_HOME}/config/genesis.json")
echo $genesisJson > "${CUDOS_HOME}/config/genesis.json"
genesisJson=$(jq ".app_state.crisis.constant_fee.denom = \"$BOND_DENOM\"" "${CUDOS_HOME}/config/genesis.json")
echo $genesisJson > "${CUDOS_HOME}/config/genesis.json"

# government proposal params
genesisJson=$(jq ".app_state.gov.params.min_deposit[0].amount = \"50000000000000000000000\"" "${CUDOS_HOME}/config/genesis.json")
echo $genesisJson > "${CUDOS_HOME}/config/genesis.json"
genesisJson=$(jq ".app_state.gov.params.min_deposit[0].denom = \"$BOND_DENOM\"" "${CUDOS_HOME}/config/genesis.json")
echo $genesisJson > "${CUDOS_HOME}/config/genesis.json"
genesisJson=$(jq ".app_state.gov.params.max_deposit_period = \"$PARAM_MAX_DEPOSIT_PERIOD\"" "${CUDOS_HOME}/config/genesis.json")
echo $genesisJson > "${CUDOS_HOME}/config/genesis.json"
genesisJson=$(jq ".app_state.gov.params.voting_period = \"$PARAM_VOTING_PERIOD\"" "${CUDOS_HOME}/config/genesis.json")
echo $genesisJson > "${CUDOS_HOME}/config/genesis.json"
genesisJson=$(jq ".app_state.gov.params.quorum = \"0.5\"" "${CUDOS_HOME}/config/genesis.json")
echo $genesisJson > "${CUDOS_HOME}/config/genesis.json"
genesisJson=$(jq ".app_state.gov.params.threshold = \"0.5\"" "${CUDOS_HOME}/config/genesis.json")
echo $genesisJson > "${CUDOS_HOME}/config/genesis.json"
genesisJson=$(jq ".app_state.gov.params.veto_threshold = \"0.4\"" "${CUDOS_HOME}/config/genesis.json")
echo $genesisJson > "${CUDOS_HOME}/config/genesis.json"

# distribution params
genesisJson=$(jq ".app_state.distribution.params.community_tax = \"0.2\"" "${CUDOS_HOME}/config/genesis.json")
echo $genesisJson > "${CUDOS_HOME}/config/genesis.json"

# fractions metadata
genesisJson=$(jq ".app_state.bank.denom_metadata[0].description = \"The native staking token of the Cudos Hub\"" "${CUDOS_HOME}/config/genesis.json")
echo $genesisJson > "${CUDOS_HOME}/config/genesis.json"
genesisJson=$(jq ".app_state.bank.denom_metadata[0].base = \"$BOND_DENOM\"" "${CUDOS_HOME}/config/genesis.json")
echo $genesisJson > "${CUDOS_HOME}/config/genesis.json"
genesisJson=$(jq ".app_state.bank.denom_metadata[0].name = \"cudos\"" "${CUDOS_HOME}/config/genesis.json")
echo $genesisJson > "${CUDOS_HOME}/config/genesis.json"
genesisJson=$(jq ".app_state.bank.denom_metadata[0].symbol = \"CUDOS\"" "${CUDOS_HOME}/config/genesis.json")
echo $genesisJson > "${CUDOS_HOME}/config/genesis.json"
genesisJson=$(jq ".app_state.bank.denom_metadata[0].display = \"cudos\"" "${CUDOS_HOME}/config/genesis.json")
echo $genesisJson > "${CUDOS_HOME}/config/genesis.json"

genesisJson=$(jq ".app_state.bank.denom_metadata[0].denom_units = [
  {
    \"denom\": \"acudos\",
    \"exponent\": \"0\",
    \"aliases\": [ \"attocudos\" ]
  }, {
    \"denom\": \"fcudos\",
    \"exponent\": \"3\",
    \"aliases\": [ \"femtocudos\" ]
  }, {
    \"denom\": \"pcudos\",
    \"exponent\": \"6\",
    \"aliases\": [ \"picocudos\" ]
  }, {
    \"denom\": \"ncudos\",
    \"exponent\": \"9\",
    \"aliases\": [ \"nanocudos\" ]
  }, {
    \"denom\": \"ucudos\",
    \"exponent\": \"12\",
    \"aliases\": [ \"microcudos\" ]
  }, {
    \"denom\": \"mcudos\",
    \"exponent\": \"15\",
    \"aliases\": [ \"millicudos\" ]
  }, {
    \"denom\": \"cudos\",
    \"exponent\": \"18\"
  }
]" "${CUDOS_HOME}/config/genesis.json")
echo $genesisJson > "${CUDOS_HOME}/config/genesis.json"

# gravity params
gravityId=$(echo $RANDOM | sha1sum | head -c 31)
genesisJson=$(jq ".app_state.gravity.params.gravity_id = \"$gravityId\"" "${CUDOS_HOME}/config/genesis.json")
echo $genesisJson > "${CUDOS_HOME}/config/genesis.json"
genesisJson=$(jq ".app_state.gravity.erc20_to_denoms[0] |= .+ {
  \"erc20\": \"$CUDOS_TOKEN_CONTRACT_ADDRESS\",
  \"denom\": \"acudos\"
}" "${CUDOS_HOME}/config/genesis.json")
echo $genesisJson > "${CUDOS_HOME}/config/genesis.json"
genesisJson=$(jq ".app_state.gravity.params.minimum_transfer_to_eth = \"1\"" "${CUDOS_HOME}/config/genesis.json")
echo $genesisJson > "${CUDOS_HOME}/config/genesis.json"
genesisJson=$(jq ".app_state.gravity.params.minimum_fee_transfer_to_eth = \"1200000000000000000000\"" "${CUDOS_HOME}/config/genesis.json")
echo $genesisJson > "${CUDOS_HOME}/config/genesis.json"

# mint params
genesisJson=$(jq ".app_state.cudoMint.minter.norm_time_passed = \"0.53172694105988\"" "${CUDOS_HOME}/config/genesis.json")
echo $genesisJson > "${CUDOS_HOME}/config/genesis.json"

# create zero account
(echo $KEYRING_OS_PASS; echo $KEYRING_OS_PASS) | cudos-noded keys add zero-account --keyring-backend test --home=$CUDOS_HOME > "${CUDOS_HOME}/zero-account.wallet"
chmod 600 "${CUDOS_HOME}/zero-account.wallet"
ZERO_ACCOUNT_ADDRESS=$(echo $KEYRING_OS_PASS | cudos-noded keys show zero-account -a --keyring-backend test --home=$CUDOS_HOME)
cudos-noded add-genesis-account $ZERO_ACCOUNT_ADDRESS "1${BOND_DENOM}" --home=$CUDOS_HOME

# create admin account and save mnemonic
(echo $KEYRING_OS_PASS; echo $KEYRING_OS_PASS) | cudos-noded keys add test-admin --keyring-backend test --home=$CUDOS_HOME 2>&1 | grep -A3 'Important' | tail -1 > "${CUDOS_HOME}/test-admin.wallet"
chmod 600 "${CUDOS_HOME}/test-admin.wallet"
TEST_ADMIN_ADDRESS=$(echo $KEYRING_OS_PASS | cudos-noded keys show test-admin -a --keyring-backend test --home=$CUDOS_HOME)
cudos-noded add-genesis-account $TEST_ADMIN_ADDRESS "10cudosAdmin, 100000000000000000000000000${BOND_DENOM}" --home=$CUDOS_HOME

for i in $(seq 1 $NUMBER_OF_VALIDATORS); do
    if [ "$i" = "1" ] && [ "$ROOT_VALIDATOR_MNEMONIC" != "" ]; then
        (echo $ROOT_VALIDATOR_MNEMONIC; echo $KEYRING_OS_PASS) | cudos-noded keys add "validator-$i" --recover --keyring-backend test --home=$CUDOS_HOME
    else
        (echo $KEYRING_OS_PASS; echo $KEYRING_OS_PASS) | cudos-noded keys add "validator-$i" --keyring-backend test --home=$CUDOS_HOME > "${CUDOS_HOME}/validator-$i.wallet"
        chmod 600 "${CUDOS_HOME}/validator-$i.wallet"
    fi
    validatorAddress=$(echo $KEYRING_OS_PASS | cudos-noded keys show validator-$i -a --keyring-backend test --home=$CUDOS_HOME)
    cudos-noded add-genesis-account $validatorAddress "${VALIDATOR_BALANCE}${BOND_DENOM}" --home=$CUDOS_HOME
    cat "${CUDOS_HOME}/config/genesis.json" | jq --arg validatorAddress "$validatorAddress" '.app_state.gravity.static_val_cosmos_addrs += [$validatorAddress]' > "${CUDOS_HOME}/config/tmp_genesis.json" && mv "${CUDOS_HOME}/config/tmp_genesis.json" "${CUDOS_HOME}/config/genesis.json"
done

for i in $(seq 1 $NUMBER_OF_ORCHESTRATORS); do
    (echo $KEYRING_OS_PASS; echo $KEYRING_OS_PASS) | cudos-noded keys add "orch-$i" --keyring-backend test --home=$CUDOS_HOME > "${CUDOS_HOME}/orch-$i.wallet"
    chmod 600 "${CUDOS_HOME}/orch-$i.wallet"
    orchAddress=$(echo $KEYRING_OS_PASS | cudos-noded keys show orch-$i -a --keyring-backend test --home=$CUDOS_HOME)    
    cudos-noded add-genesis-account $orchAddress "${ORCHESTRATOR_BALANCE}${BOND_DENOM}" --home=$CUDOS_HOME
    if [ "$i" = "1" ]; then
        ORCH_01_ADDRESS="$orchAddress"
    fi
done

# add faucet account
if [ "$FAUCET_BALANCE" != "" ] && [ "$FAUCET_BALANCE" != "0" ]; then
    ((echo $KEYRING_OS_PASS; echo $KEYRING_OS_PASS) | cudos-noded keys add faucet --keyring-backend test --home=$CUDOS_HOME ) > "${CUDOS_HOME}/faucet.wallet"
    chmod 600 "${CUDOS_HOME}/faucet.wallet"
    FAUCET_ADDRESS=$(echo $KEYRING_OS_PASS | cudos-noded keys show faucet -a --keyring-backend test --home=$CUDOS_HOME)
    cudos-noded add-genesis-account $FAUCET_ADDRESS "${FAUCET_BALANCE}${BOND_DENOM}" --home=$CUDOS_HOME
fi

# Setting gravity module account and funding it as per parameter
genesisJson=$(jq ".app_state.auth.accounts += [{
  \"@type\": \"/cosmos.auth.v1beta1.ModuleAccount\",
  \"base_account\": {
    \"account_number\": \"0\",
    \"address\": \"cudos16n3lc7cywa68mg50qhp847034w88pntq8823tx\",
    \"pub_key\": null,
    \"sequence\": \"0\"
  },
  \"name\": \"gravity\",
  \"permissions\": [
    \"minter\",
    \"burner\"
  ]
}]" "${CUDOS_HOME}/config/genesis.json")
echo $genesisJson > "${CUDOS_HOME}/config/genesis.json"

if [ "$GRAVITY_MODULE_BALANCE" != "" ] && [ "$GRAVITY_MODULE_BALANCE" != "0" ]; then
  genesisJson=$(jq ".app_state.bank.balances += [{
    \"address\": \"cudos16n3lc7cywa68mg50qhp847034w88pntq8823tx\",
    \"coins\": [
      {
        \"amount\": \"$GRAVITY_MODULE_BALANCE\",
        \"denom\": \"acudos\"
      }
    ]
  }]" "${CUDOS_HOME}/config/genesis.json")
  echo $genesisJson > "${CUDOS_HOME}/config/genesis.json"
fi

(echo $KEYRING_OS_PASS; echo $KEYRING_OS_PASS) | cudos-noded gentx validator-1 "${VALIDATOR_BALANCE}${BOND_DENOM}" ${ORCH_ETH_ADDRESS} ${ORCH_01_ADDRESS} --min-self-delegation 2000000000000000000000000 --chain-id $CHAIN_ID --keyring-backend test --home=$CUDOS_HOME

cudos-noded collect-gentxs --home=$CUDOS_HOME

cudos-noded tendermint show-node-id --home=$CUDOS_HOME > "${CUDOS_HOME}/tendermint.nodeid"

chmod 755 "${CUDOS_HOME}/config"

if [ "$CHAIN_ID" != "a-chain" ]; then
  # remap default ports
  # from 1317, 9090, 9091, 26658, 26657, 26656, 26660, 6060
  # to   1316, 9088, 9089, 26655, 26654, 26652, 26666, 6061


  # change app.toml values
  APP_TOML=$CUDOS_HOME/config/app.toml

  sed -i -E 's|tcp://localhost:1317|tcp://localhost:1316|g' $APP_TOML
  sed -i -E 's|localhost:9090|localhost:9088|g' $APP_TOML
  sed -i -E 's|localhost:9091|localhost:9089|g' $APP_TOML

  # change config.toml values
  CONFIG=$CUDOS_HOME/config/config.toml

  sed -i -E 's|tcp://127.0.0.1:26658|tcp://127.0.0.1:26655|g' $CONFIG
  sed -i -E 's|tcp://0.0.0.0:26657|tcp://0.0.0.0:26654|g' $CONFIG
  sed -i -E 's|tcp://0.0.0.0:26656|tcp://0.0.0.0:26652|g' $CONFIG
  sed -i -E 's|:26660|:26666|g' $CONFIG
  sed -i -E 's|allow_duplicate_ip = false|allow_duplicate_ip = true|g' $CONFIG
fi

# start node as daemon (in background)
echo "Starting $CHAIN_ID"
sleep 3
cudos-noded start --home=$CUDOS_HOME &> /dev/null &
echo "$CHAIN_ID started in background"
