This is a POC to demonstrate the usage of a single CosmWasm contract to create an ICA address on a remote host chain over IBC and execute a TX on the targeted chain. The interesting part is that the target chain might not have Wasm module at all, as the contract that we are using communicates directly with the ICA module of the target chain.

## Pre-requisites
    Rust 1.70
    Go 1.20
    Docker


## USAGE
1. No additinal ENV set up is required, so just navigate to project root and do:

```sh 
$ chmod +x ./run.sh && ./run.sh
```

The flow of the script is:
   1. Compiles an ICA controller CosmWasm contract
   2. Set up 2 identical Cudos chains (***as background processes***)
        - A-chain - Controller / :26657
        - B-chain - Target / :26654 
   3. Store and instantiate the controller contract on A-chain
   4. Set up Hermes IBC Relayer (***as background process***) and establish a connection between the controller contract that is now instantiated on A-chain and ICA host module on B-chain
   5. After a successful connection we have an ICA address assigned from B-chain to our contract. That address can also be found at  ```./project_root/config/ica.address ``` 
   6. TODO...

# Caveats
 Sometimes Hermes might ERROR during the handshake process with ```account sequence mismatch```, which is known problem and should not impact how the connection is established afterwards as it will be retried. In case of script execution failure, please re-start it.