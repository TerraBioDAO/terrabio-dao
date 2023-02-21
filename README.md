# Foundry template

## Initialisation

```sh
forge init myProject
cd myProject
```

## Install dependencies

```sh
cd myProject
forge install <https://github.com/library-to-import>@branch
```

## Import lib in contracts (via remappings)

```sh
forge remappings > remappings.txt
```

```sh
# ./remappings.txt
ds-test/=lib/forge-std/lib/ds-test/src/
forge-std/=lib/forge-std/src/
openzeppelin-contracts/=lib/openzeppelin-contracts/contracts
```

**Import in contract:**

```sol
// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";

contract AnyContract is Ownable {}
```

## Compile contract

Set compiler version in `foundry.toml`

```toml
solc = "0.8.13"
```

Compile and log contracts sizes:

```sh
forge build --sizes
```

Inspect compiled contracts:

```sh
forge inspect <contract_name> <element_to_inspect>
```

_Contract metadata:_

```sh
forge inspect <contract_name> metadata
```

_bytecode:_

```sh
forge inspect <contract_name> bytecode
```

_abi:_

```sh
forge inspect <contract_name> abi
```

Inspect `storage` can be very useful:

```sh
forge inspect <contract_name> storage --pretty
```

## Unit testing

Create file in `test/AnyContract.t.sol`

Import the testing library in the test contract:

```sol
// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {VmSafe} from "forge-std/Vm.sol";

import {AnyContract} from "src/AnyContract.sol";

contract AnyContract_test is Test {}
```

Add a `setUp` function for "beforeAll" conditions:

```sol
{...}
import {AnyContract} from "src/AnyContract.sol";

contract AnyContract_test is Test {
  function setUp() public {
    AnyContract anyContract = new AnyContract();
  }
}
```

Create an unit test with function starting with `test`:

```sol
{...}

contract AnyContract_test is Test {
  {...}

  function test_functionName_ConditionToTest() public {}
}
```

Run tests with differents amount of details

```sh
forge test
forge test -vv
forge test -vvvv
```

Read about the Test library:
[Assertion cheatcodes](https://book.getfoundry.sh/reference/ds-test)
[Execution environment cheatcode](https://book.getfoundry.sh/cheatcodes/)

### Forking a network in tests

Set a network in `foundry.toml`:

```toml
[rpc_endpoints]
anvil = "http://localhost:8545/"
goerli = "https://ethereum-goerli-rpc.allthatnode.com"
```

RPC urls can be founds on [chainlist.org](https://chainlist.org/), consider using an API KEY with nodes providers (like Infura, POKT network, ...) for large amount of transactions or calls.

**Fork the network for the whole tests:**

```sh
forge test -f goerli
```

**Fork the network only in specific tests:**

```sol
{...}

contract AnyContract_test is Test {
  {...}

  function test_functionName_ForkCondition() public {
    vm.createSelectFork("goerli");

    // try by logging chain variable
    emit log_named_uint("chain ID", block.chainid);
    emit log_named_uint("block height", block.number);
  }
}
```

**Increase tests speed by caching calls to the forked network:**

```sol
{...}

contract AnyContract_test is Test {
  {...}

  function test_functionName_ForkCondition() public {
    // stick to a specific block number
    vm.createSelectFork("goerli", 8486194);

    emit log_named_uint("chain ID", block.chainid);
    emit log_named_uint("block height", block.number);
  }
}
```

_Foundry will cache all calls sended to the forked network, so the next time `forge test` is run, data are fetched in the cache instead of the network._

**Check Foundry cache:**

```sh
forge cache ls
```

## Deploy contracts

Write scripts in `script/my_script.s.sol` and import the script library:

```sol
// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import "forge-std/Script.sol";

import {AnyContract} from "src/AnyContract.sol";

contract deploy is Script {}
```

_You can add private keys in `.env` and read them in the script:_

```
DEPLOYER_ANVIL=ac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```

Add the "broadcast" block to sign transaction with a specific private key:

```sol
contract deploy is Script {
  function run() public {
    // read private key in .env
    uint256 pk = vm.envUint("DEPLOYER_ANVIL");
    address deployer = vm.addr(pk);

    // broadcast block
    vm.startBroadcast(pk);

    // deploy and call contracts here

    vm.stopBroadcast();
  }
}
```

Test your script with:

```sh
forge script deploy
```

_Foundry will execute the function `run()` in your script._

### Using local blockchain

Launch the local blockchain with:

```
anvil
```

**Dry run your script on the network:**

```sh
forge script deploy --rpc-url anvil
```

Dry allow to run your script and create transaction which can be checked in `broadcast`

**Run and broadcast transaction:**

```sh
forge script deploy --rpc-url anvil --broadcast
```

### Using testnet

Dry run your script is always a good practice:

```sh
forge script deploy --rpc-url goerli
```

Then:

```sh
forge script deploy --rpc-url goerli --broadcast
```

## Verify contract

**[Sourcify](https://sourcify.dev/):**

```
forge verify-contract <address> <contract_name> --chain <chain_id> --verifier sourcify
```

**Etherscan:**
Make sure you have set the `ETHERSCAN_KEY` in `.env`

```
source .env
forge verify-contract <address> <contract_name> --chain <network_alias | chain_id> $ETHERSCAN_KEY --watch
```

If the contract has been deployed with arguments:

```
cast abi-encode "constructor(address,uint256)" 0xdaab... 500000
```

Then add the flag `--constructor-args` with the above result to the `forge verify-contract` command

---

**Contributors:** Raph, xDrKush, Yamakhala, Amine
