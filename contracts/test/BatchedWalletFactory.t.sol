// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.12 <=0.8.20;

import {Test} from "forge-std/Test.sol";
import {BatchedWallet} from "../src/BatchedWallet.sol";
import {BatchedWalletFactory} from "../src/BatchedWalletFactory.sol";
import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";

import "forge-std/console2.sol";


contract BatchedWalletTest is Test {
    BatchedWallet public bw;
    BatchedWalletFactory public bwFactory;
    IEntryPoint entryPoint = IEntryPoint(address(10101));
    address user = address(12345);
    uint256 salt = 12345; 

    function setUp() public {
        bwFactory = new BatchedWalletFactory(entryPoint);
    }
    
    function testBatchedWalletDeployment() public{
        vm.prank(user);
        BatchedWallet batchedWallet = bwFactory.createAccount(user, salt);
        assertEq(address(batchedWallet), bwFactory.getAddress(user, salt));
    }

    function testBatchedWalletEntryPoint() public{
        vm.prank(user);
        BatchedWallet batchedWallet = bwFactory.createAccount(user, salt);
        assertEq(address(batchedWallet.entryPoint()), address(entryPoint));
    }

    function testBatchedWalletOwner() public{
        vm.prank(user);
        BatchedWallet batchedWallet = bwFactory.createAccount(user, salt);
        assertEq(batchedWallet.owner(), user);
    }
}
