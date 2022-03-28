Setting up the network
  - The StarkNet CLI is used to interact with StarkNet (in this tutorial)
  - In order to instruct the CLI to work with the StarkNet testnet you can
    - Add `--network=alpha-goerli` flag to every command
    - Set `STARKNET_NETWORK` as an environment variable as follows
      - `export STARKNET_NETWORK=aplha-goerli`
      - I placed this in a file `environment_variables.sh`, so run `source environment_variables.sh`

Choosing a wallet provider
  - StarkNet doesn't have a distinction between EOAs and CAs
    - Instead an account is represented by a deployed contract that defines the account's logic
    - Most notable the signature scheme that controls who can issue transactions from it
  - To interact with StarkNet you need to deploy an "account contract"
    - Will use a slightly modified version of OZ's standard for EOA contract
    - Set the `STARKNET_WALLET` environment variables as follows
      - `export STARKNET_WALLET=starkware.starknet.wallets.open_zeppelin.OpenZeppelinAccount`

Create an account
  - Run the following command to create an account
    - `starknet deploy_account`
      - The flag `--account=<account_name>` can be used to name the account
      - Otherwise the default name of `__default__` will be used
  - Output should show the contract address, public key and transaction hash
  - The `STARKNET_WALLET` environment variable tells the StarkNet CLI to use your account in the `starknet_invoke` and `starknet_call` commands.
    - If you cant to direct call a contract without passing through your account contract use the `--no_wallet` argument in the CLI

Transferring Goerli ETH to the account
  - In order to execute TXs on StarkNet you need to have ETH in your L2 account (for paying TX fees)
  - L2 ETH can be acquired in the following ways
    - Use the [StarkNet Faucet](https://faucet.goerli.starknet.io/) to get ETH directly to your created account
    - Use the StarkNet L2 bridge (not out yet) to transfer existing Goerli L1 ETH to and from the L2 account
