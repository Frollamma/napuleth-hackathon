# TesserAct

## Requirements

Before you begin, you need to install the following tools:

- [Node (>= v20.18.3)](https://nodejs.org/en/download/)
- Yarn ([v1](https://classic.yarnpkg.com/en/docs/install/) or [v2+](https://yarnpkg.com/getting-started/install))
- [Git](https://git-scm.com/downloads)

## Install

1. Clone this repo

2. Be sure submodules have been downloaded:

```sh
git submodule update --init --recursive
```

3. Install dependencies

```sh
cd my-dapp-example
yarn install
```

## Extra install (base sepolia)

Follow [this guide](https://docs.base.org/learn/foundry/deploy-with-foundry) to set up your environment to deploy on base sepolia. There's also a `.env.example` that you can copy to `.env` to help you.

## Extra install (avalanche)

Follow [this guide](https://build.avax.network/docs/tooling/create-avalanche-l1) to set up your environment to deploy locally on your avalanche L1.

To set the PATH fish use this:

```
set -x PATH ~/bin $PATH
```

If everything goes well you'll see:

```
prefunding address 0x8db97C7cEcE249c2b98bDC0226Cc4C2A57BF52FC with balance 1000000000000000000000000
Installing subnet-evm-v0.7.5...
subnet-evm-v0.7.5 installation successful
File /home/frollo/.avalanche-cli/subnets/myblockchain/chain.json successfully written
✓ Successfully created blockchain configuration
Run 'avalanche blockchain describe' to view all created addresses and what their roles are
```

## Run (local)

You can run on a local chain by following these steps:

1. Run a local network in the first terminal:

```sh
yarn chain
```

This command starts a local Ethereum network using Foundry. The network runs on your local machine and can be used for testing and development. You can customize the network configuration in `packages/foundry/foundry.toml`.

2. On a second terminal, deploy the contracts:

```sh
yarn deploy
```

3. On a third terminal, start your NextJS app:

```sh
yarn start
```

Visit `http://localhost:3000`.

## Run (base sepolia)

You can run on Base Sepolia by following these steps:

1. In a first terminal, deploy the contracts:

```sh
yarn deploy-base-sepolia
```

2. On a second terminal, start your NextJS app:

```sh
yarn start
```

Visit `http://localhost:3000`.

## Run (avalanche)

You can run on Avalanche by following these steps:

1. In a first terminal, deploy the contracts:

```sh
yarn deploy-avalanche
```

2. On a second terminal, start your NextJS app:

```sh
yarn start
```

Visit `http://localhost:3000`.

## Documentation

Please to understand how everything works visit the `docs`.

## License

This project is licensed under the Business Source License 1.1.  
See the [LICENSE](./LICENSE) file for details.
