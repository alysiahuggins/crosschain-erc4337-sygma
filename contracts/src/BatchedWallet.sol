// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.12 <=0.8.20;

import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";
import {BaseAccount} from "account-abstraction/core/BaseAccount.sol";
import {UserOperation} from "account-abstraction/interfaces/UserOperation.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {TokenCallbackHandler} from "./callback/TokenCallbackHandler.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";


contract BatchedWallet is Initializable, BaseAccount, TokenCallbackHandler, UUPSUpgradeable{
    using ECDSA for bytes32;

    address public owner;
    IEntryPoint private immutable _entryPoint;

    event BatchedWalletInitialized(IEntryPoint indexed entryPoint, address owners);
    event WithdrawERC20(address indexed _to, address _token, uint256 _amount);

    modifier _requireFromEntryPointOrOwner() {
        require(
            msg.sender == address(_entryPoint) || msg.sender == owner,
            "only entry point or wallet owner can call"
        );
        _;
    }

    modifier onlyOwner() {
        _onlyOwner();
        _;
    }

    constructor(IEntryPoint batchedWalletEntryPoint){
        _entryPoint = batchedWalletEntryPoint;
        _disableInitializers(); //prevent the this implementation from being used by locking it
    }

    receive() external payable {}


    function _onlyOwner() internal view {
        //directly from EOA owner, or through the account itself (which gets redirected through execute())
        require(msg.sender == owner || msg.sender == address(this), "only owner");
    }

    function initialize(address walletOwner) public initializer {
        _initialize(walletOwner);
    }

    function _initialize(address walletOwner) internal virtual {
        owner = walletOwner;
        emit BatchedWalletInitialized(_entryPoint, owner);
    }

    /**
    execute a transaction directly from user or entry point*/
    function execute(address dest, uint256 value, bytes calldata func) 
    external 
    _requireFromEntryPointOrOwner{
        _call(dest, value, func);
    }

    /**
    executes batch of transactions directly from user or entry point */
    function executeBatch(address[] calldata dest, bytes[] calldata func) 
    external 
    _requireFromEntryPointOrOwner{
        require(dest.length == func.length, "wrong array lengths");
        for (uint256 i = 0; i < dest.length; i++) {
            _call(dest[i], 0, func[i]);
        }
    }

    /**
    executes batch of transactions directly from user or entry point with Value */
    function executeBatchWithValue(address[] calldata dest, uint256[] calldata value, bytes[] calldata func) 
    external 
    _requireFromEntryPointOrOwner{
        require(dest.length == func.length && (value.length == 0 || value.length == func.length), "wrong array lengths");
        if (value.length == 0) {
            for (uint256 i = 0; i < dest.length; i++) {
                _call(dest[i], 0, func[i]);
            }
        } else {
            for (uint256 i = 0; i < dest.length; i++) {
                _call(dest[i], value[i], func[i]);
            }
        }
    }

    /**
    * _call helps us make abritrary function calls through this smart contract
    */
    function _call(address target, uint256 value, bytes memory data) internal {
        (bool success, bytes memory result) = target.call{value : value}(data);
        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
    }

    function entryPoint() public view override returns (IEntryPoint) {
        return _entryPoint;
    }

    function _validateSignature(UserOperation calldata userOp, bytes32 userOpHash)
    internal 
    override 
    virtual 
    returns (uint256 validationData) {
        bytes32 hash = MessageHashUtils.toEthSignedMessageHash(userOpHash);
        if (owner != hash.recover(userOp.signature))
            return SIG_VALIDATION_FAILED;
        return 0;
    }

    /**
     * check current account deposit in the entryPoint
     */
    function getDeposit() public view returns (uint256) {
        return entryPoint().balanceOf(address(this));
    }

    /**
     * deposit more funds for this account in the entryPoint
     */
    function addDeposit() public payable {
        entryPoint().depositTo{value : msg.value}(address(this));
    }

    /**
     * withdraw value from the account's deposit
     */
    function withdrawDepositTo(address payable withdrawAddress, uint256 amount) public onlyOwner {
        entryPoint().withdrawTo(withdrawAddress, amount);
    }

    /** 
    Withdraw ERC20 tokens from the wallet. Permissioned to only the owner
    */
    function withdrawERC20To(address token, address to, uint256 amount) external onlyOwner {
        SafeERC20.safeTransfer(IERC20(token), to, amount);
        emit WithdrawERC20(to, token, amount);
    }

    /** 
    Withdraw ETH tokens from the wallet. Permissioned to only the owner
    */
    function withdrawETHTo(address to) external onlyOwner {
        payable(to).transfer(address(this).balance);
    }

    function _authorizeUpgrade(address newImplementation) internal view override{
        (newImplementation);
        _onlyOwner();
    }

}
