// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.12 <=0.8.20;

import "forge-std/Script.sol";
import "../src/TestERC20.sol";

contract BatchedWalletTokenScript is Script {

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY"); // Fetch the private key from environment variables
        vm.startBroadcast(deployerPrivateKey); // Start broadcasting transactions
        new BatchedWalletToken(); // Initialize the WalletFactory contract
        vm.stopBroadcast(); // Stop broadcasting transactions

    }
}