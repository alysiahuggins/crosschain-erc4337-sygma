// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.12 <=0.8.20;

import {Test, console2, Vm} from "forge-std/Test.sol";
import {BatchedWallet} from "../src/BatchedWallet.sol";
import {BatchedWalletFactory} from "../src/BatchedWalletFactory.sol";
import {BatchedWalletToken} from "../src/TestERC20.sol";
import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";
import {UserOperation} from "account-abstraction/interfaces/UserOperation.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


contract BatchedWalletTest is Test {
    BatchedWallet public bw;
    IEntryPoint entryPoint = IEntryPoint(address(10101));
    BatchedWalletToken bwt;
    uint256 chainId = block.chainid;
    address alice = makeAddr('alice');
    uint salt = 12345;

    function setUp() public {
        BatchedWalletFactory bwFactory = new BatchedWalletFactory(entryPoint);

        vm.startPrank(alice);
        bw = bwFactory.createAccount(alice, salt);
        vm.deal(address(bw), 1 ether);
        vm.stopPrank();

        bwt = new BatchedWalletToken();


    }

    function testOwner() public{
        assertEq(bw.owner(), alice);
    }

    function testEntryPoint() public{
        assertEq(address(bw.entryPoint()), address(entryPoint));
    }
    function testExecute() public {
        address bob = makeAddr('bob');

        vm.startPrank(alice);
        bw.execute(bob, 0.001 ether, "");
        assertEq(bob.balance, 0.001 ether);
        assertEq(address(bw).balance, 0.999 ether);
        vm.stopPrank();
    }

    function testExecuteFailWithWrongOwner() public {
        address bob = makeAddr('bob');

        vm.startPrank(bob);
        vm.expectRevert();

        bw.execute(bob, 0.001 ether, "");
        
        vm.stopPrank();
    }

    function testDepositETH() public {
        uint etherAmount = 5 ether;
        vm.deal(address(bw), etherAmount);
        assertEq(address(bw).balance, etherAmount);
    }

    function testERC20Mint() public {
        vm.startPrank(alice); //alice is the owner of the wallet object, bw
        uint mintAmount = 5 ether;
        bytes memory funcData = abi.encodeWithSelector(BatchedWalletToken.mint.selector, address(bw), mintAmount);
        bw.execute(address(bwt), 0, funcData); //have the wallet send a transaction to the token and request a mint 
        assertEq(bwt.balanceOf(address(bw)), mintAmount);
        vm.stopPrank();
    }

    function testERC20Transfer() public {
        vm.startPrank(alice); //alice is the owner of the wallet object, bw

        //mint erc20 tokens to the wallet
        uint mintAmount = 5 ether;
        bytes memory funcData = abi.encodeWithSelector(BatchedWalletToken.mint.selector, address(bw), mintAmount);
        bw.execute(address(bwt), 0, funcData); //have the wallet send a transaction to the token and request a mint 
        assertEq(bwt.balanceOf(address(bw)), mintAmount);

        uint transferAmount = 2 ether;
        address bob = makeAddr('bob');
        bytes memory transferFuncData = abi.encodeWithSelector(ERC20.transfer.selector, bob, transferAmount); 
        bw.execute(address(bwt), 0, transferFuncData); //have the wallet send a transaction to the token and request a mint 
        assertEq(bwt.balanceOf(bob), transferAmount);
    }

    function testBatchERC20MintAndTransfer() public{
        uint mintAmount = 5 ether;
        uint transferAmount = 2 ether;
        address bob = makeAddr('bob');
        uint numOps = 2;

        //prepare the destinations and function data for the transfer
        address [] memory dest = new address[](numOps);
        bytes [] memory data = new bytes[](numOps);
        dest[0] = address(bwt);
        dest[1] = address(bwt);
        data[0] = abi.encodeWithSelector(
            BatchedWalletToken.mint.selector, 
            address(bw), 
            mintAmount);
        data[1] = abi.encodeWithSelector(
            ERC20.transfer.selector, 
            bob, 
            transferAmount);

        //perform batch transfer
        vm.startPrank(alice);
        bw.executeBatch(dest, data);
        assertEq(bwt.balanceOf(address(bw)), mintAmount - transferAmount);
        assertEq(bwt.balanceOf(bob), transferAmount);
        vm.stopPrank();

    }

    function testExecuteBatchWithValues() public{
        uint etherAmount = 5 ether;
        uint numOps = 2;
        uint transferAmount = 2 ether;
        address bob = makeAddr('bob');
        address john = makeAddr('john');

        //send ether to alice's smart wallet
        vm.deal(address(bw), etherAmount);
        assertEq(address(bw).balance, etherAmount);


        //prepare the destinations, values  for the transfer
        address [] memory dest = new address[](numOps);
        uint256 [] memory value = new uint256[](numOps);
        bytes [] memory data = new bytes[](numOps);
        dest[0] = bob;
        dest[1] = john;
        value[0] = transferAmount;
        value[1] = transferAmount;

        //perform batch transfer
        vm.startPrank(alice);
        bw.executeBatchWithValue(dest, value, data);
        assertEq(address(bw).balance, etherAmount - (transferAmount*numOps));
        assertEq(bob.balance, transferAmount);
        assertEq(john.balance, transferAmount);
        vm.stopPrank();
    }


    function testWithdrawERC20() public{
        vm.startPrank(alice); //alice is the owner of the wallet object, bw
        uint mintAmount = 5 ether;
        bytes memory funcData = abi.encodeWithSelector(BatchedWalletToken.mint.selector, address(bw), mintAmount);
        bw.execute(address(bwt), 0, funcData); //have the wallet send a transaction to the token and request a mint 
        assertEq(bwt.balanceOf(address(bw)), mintAmount);

        bytes memory withdrawERC20FuncData = abi.encodeWithSelector(ERC20.transfer.selector, alice, mintAmount);
        bw.execute(address(bwt), 0, withdrawERC20FuncData); //have the wallet send a transaction to the token and request a mint 
        assertEq(bwt.balanceOf(alice), mintAmount);

        vm.stopPrank();
    } 
    
    function testWithdrawERC20WithoutExecute() public{
        vm.startPrank(alice); //alice is the owner of the wallet object, bw
        uint mintAmount = 5 ether;
        bytes memory funcData = abi.encodeWithSelector(BatchedWalletToken.mint.selector, address(bw), mintAmount);
        bw.execute(address(bwt), 0, funcData); //have the wallet send a transaction to the token and request a mint 
        assertEq(bwt.balanceOf(address(bw)), mintAmount);

        bw.withdrawERC20To(address(bwt), alice, mintAmount);
        assertEq(bwt.balanceOf(alice), mintAmount);

        vm.stopPrank();
    }

    function testWithdrawETH0WithoutExecute() public{
        vm.startPrank(alice); //alice is the owner of the wallet object, bw
        uint etherAmount = 5 ether;
        vm.deal(address(bw), etherAmount);
        
        bw.withdrawETHTo(alice);
        assertEq(alice.balance, etherAmount);

        vm.stopPrank();
    }
    
}
