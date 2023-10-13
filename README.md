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
   4. Set up Hermes IBC Relayer (***as background process***), establishes connection and opens a channel between the controller contract that is now instantiated on A-chain and ICA host module on B-chain
   5. After a successful connection we have an ICA address assigned from B-chain to our contract. That address can also be found at  ```./project_root/config/ica.address ``` 
   6. Funds this account, so it can execute TXs on B-chain on the behalf of it's controller from A-chain and verify the balance.
   7. Creates new empty balanced account on B-chain, which will serve in the IBC test afterwards, and verify it's empty balance.
   8. Next it executes the test
       - Sends a msg to the wasm contract on A-chain
       - The contract broadcasts a respective IBCmsg on A-chain
       - The Hermes relayer picks it up and relays it over IBC to B-chain.
       - B-chain executes it, which result of the ICA address on B-chain to transfer fundes to the pointed in the msg new address.
   9. Verify balance changes of the two B-chain parties - contracts ICA address and the new address we created earlier.

## Additional notes
    Beyond the one way smart contract option, we can also trigger more complex logic between A-B chains using 2 smart contracts. Practically, a host contract on B-chain, controlled by a controller contract from A-chain, is a way to plug-in/inject additional business logic into B-chain.

# Caveats
 1. Sometimes Hermes might ERROR during the handshake process with ```account sequence mismatch```, which is known problem and should not impact how the connection is established afterwards as it will be retried. In case of script execution failure, please re-start it.
 2. Hermes has been identified to not be working correctly at some environments in regard to properly listen "live" for the IBC msgs emitted by e certain chain (A-chain in our case), therefore the data packets will "hang" on the chain for indefinite amount of time. For the purpose of this test, if we ran into such case, the script will restart the relayer, allowing him to "pick up" the waiting data from the chain on its resume in order for the test to proceed.