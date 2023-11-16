// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.12 <=0.8.20;

import "forge-std/Script.sol";
import "../src/BatchedWalletFactory.sol";
import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";

contract BatchedWalletFactoryScript is Script {
    // Address of the EntryPoint contract on Goerli
    IEntryPoint constant ENTRYPOINT =
        IEntryPoint(0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789); //Stackup EntryPoint

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY"); // Fetch the private key from environment variables
        vm.startBroadcast(deployerPrivateKey); // Start broadcasting transactions
        new BatchedWalletFactory(ENTRYPOINT); // Initialize the WalletFactory contract
        vm.stopBroadcast(); // Stop broadcasting transactions

    }
}