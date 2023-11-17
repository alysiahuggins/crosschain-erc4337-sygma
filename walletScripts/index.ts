import { ethers } from 'ethers';
import { Client, Presets } from "userop";
import dotenv from 'dotenv';
dotenv.config();
import updateDotenv from 'update-dotenv'
import { ERC20_ABI } from "./abi";
import { BRIDGE_ABI } from "./abi";
import {
  createERCDepositData
} from "@buildwithsygma/sygma-sdk-core";


async function main() {

  // Create a random private key or read existing one from environment variable
  const bundlerRpcUrl = process.env.MUMBAI_BUNDLER_RPC;
  let privateKey = process.env.PRIVATE_KEY;
  const paymasterRpcUrl = process.env.MUMBAI_PAYMASTER_RPC_URL || "";
  const mumbaiRpcUrl = process.env.MUMBAI_RPC_URL;

  if(privateKey === undefined){
    const newPrivateKey = ethers.Wallet.createRandom().privateKey;
    await updateDotenv({PRIVATE_KEY:newPrivateKey});
    privateKey = newPrivateKey;
  }

  // Create a wallet instance from the private key
  const owner = new ethers.Wallet(privateKey!);

  // Entry point and factory addresses for Polygon Mumbai testnet
  const entryPointAddress = '0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789';
  const factoryAddress = '0x1767f4E178d51ED64131a81A70B5dCF59C774c43'; //if you redeploy the wallet factory then replace this address with the new contract address

  const paymasterContext = {type: "payg"};
  const paymaster = Presets.Middleware.verifyingPaymaster(
    paymasterRpcUrl,
    paymasterContext
  );

  const smartAccount = await Presets.Builder.SimpleAccount.init(
    owner,
    bundlerRpcUrl!,
    {
      entryPoint: entryPointAddress,
      factory: factoryAddress, //my smart wallet factory created on mumbai testnet
      paymasterMiddleware: paymaster, //stackup paymaster
    },
  );
  console.log('smart wallet address', smartAccount.getSender());

  const provider = new ethers.providers.JsonRpcProvider(mumbaiRpcUrl);

  //send sygma testnet tokens to the newly created smart contract address
  console.log("Give smart account SYGMA tokens");
  const tokenAddress = "0x75811b960c7acB255f9091bBAC401700E407CDB6";
    // Define the ERC-20 token contract
  const tokenContract = new ethers.Contract(tokenAddress, ERC20_ABI, provider)
  const tokenOwner = new ethers.Wallet(process.env.PRIVATE_KEY_TOKEN_OWNER!, provider);
  // Define and parse token amount. Each token has 18 decimal places. In this example we will send 1 LINK token
  const amount = ethers.utils.parseUnits("1.0", 18);
  const contractSigner = tokenContract.connect(tokenOwner)

  //Define tx and transfer token amount to the smart account address
  const tx = await contractSigner.transfer(smartAccount.getSender(), amount);
  console.log(tx.hash);

  const client = await Client.init(bundlerRpcUrl!, {
    entryPoint: entryPointAddress,
  });

  //batch approve and transfer
  console.log("Batch Cross Chain Transfer Erc20 Tokens");
  const receiverAddress = smartAccount.getSender();
  const percentageERC20HandlerAddress = "0x850c0Dfaf1E8489b6699F7D490f8B5693B226De4";
  const erc20HandlerAddress = "0x49780Df8982ADeC1989c50c3d2A7f96037f0E937";
  const bridgeAddress = "0xeAEffbadF776Da90D8e0a94D918E1CB83c12242d";


  let transferAmount1 = ethers.utils.parseEther("1");

  let dest = [
    tokenContract.address, 
    tokenContract.address,
    bridgeAddress
  ];

  const bridgeContract = new ethers.Contract(bridgeAddress, BRIDGE_ABI, provider)

  //get sdk data
  const SEPOLIA_CHAIN_ID = 11155111;
  const depositData = createERCDepositData(transferAmount1.toString(), receiverAddress, SEPOLIA_CHAIN_ID);


  let data = [
    tokenContract.interface.encodeFunctionData("approve", [percentageERC20HandlerAddress, transferAmount1]), 
    tokenContract.interface.encodeFunctionData("approve", [erc20HandlerAddress, transferAmount1]),
    bridgeContract.interface.encodeFunctionData("deposit", [
      2, 
      "0x0000000000000000000000000000000000000000000000000000000000000300",
      depositData,
      "0x64"])
  ];
  
  const batchResult = await client.sendUserOperation(
    smartAccount.executeBatch(dest, data),
  );

  const batchEvent = await batchResult.wait();
  console.log(`Smart Wallet Cross Chain Transaction hash: ${batchEvent?.transactionHash}`);

  
}

main().catch(console.error);