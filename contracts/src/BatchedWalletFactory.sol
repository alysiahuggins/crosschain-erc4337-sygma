// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.12 <=0.8.20;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Create2} from "@openzeppelin/contracts/utils/Create2.sol";
import "./BatchedWallet.sol";

contract BatchedWalletFactory{
    BatchedWallet public immutable batchedWalletImplementation;

    constructor(IEntryPoint entryPoint) {
        batchedWalletImplementation = new BatchedWallet(entryPoint);
    }


    /**
     * create an batched wallet account, and return its address.
     * returns the address even if the account is already deployed.
     * Note that during UserOperation execution, this method is called only if the account is not deployed.
     * This method returns an existing account address so that entryPoint.getSenderAddress() would work even after account creation
     */
    function createAccount(address owner,uint256 salt) public returns (BatchedWallet ret) {
        address addr = getAddress(owner, salt);
        uint codeSize = addr.code.length;
        if (codeSize > 0) {
            return BatchedWallet(payable(addr));
        }
        ret = BatchedWallet(payable(new ERC1967Proxy{salt : bytes32(salt)}(
                address(batchedWalletImplementation),
                abi.encodeCall(BatchedWallet.initialize, (owner))
            )));
    }

    /**
    use Create2 to compute address for wallet based on the wallet owner's address and salt
    */
    function getAddress(address owner,uint256 salt) public view returns (address) {
        return Create2.computeAddress(bytes32(salt), keccak256(abi.encodePacked(
                type(ERC1967Proxy).creationCode,
                abi.encode(
                    address(batchedWalletImplementation),
                    abi.encodeCall(BatchedWallet.initialize, (owner))
                )
            )));
    }

}