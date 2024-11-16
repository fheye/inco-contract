import { task } from "hardhat/config";
import type { TaskArguments } from "hardhat/types";
import dotenv from "dotenv";
import fs from "fs";
const { createInstance } = require("fhevmjs");

const createFhevmInstance = async () => {
  let fhevmInstance = await createInstance({
    chainId: 21097,
    networkUrl: "https://validator.rivest.inco.org/",
    gatewayUrl: "https://gateway.rivest.inco.org/",
    aclAddress: "0x2Fb4341027eb1d2aD8B5D9708187df8633cAFA92",
  });

  return fhevmInstance;
};

task("task:deploy").setAction(async function (taskArguments: TaskArguments, { ethers }) {
  const signers = await ethers.getSigners();
  const faceDetectionFactory = await ethers.getContractFactory("FaceDetection");
  const faceDetection = await faceDetectionFactory.connect(signers[0]).deploy();
  await faceDetection.waitForDeployment();
  console.log("FaceDetection deployed to: ", await faceDetection.getAddress());
});

task("task:updateImage").setAction(async function (taskArguments: TaskArguments, { ethers }) {
  const signers = await ethers.getSigners();
  const signer = signers[0];
  const faceDetectionFactory = await ethers.getContractFactory("FaceDetection");
  const faceDetection = await faceDetectionFactory.connect(signer).deploy();
  await faceDetection.waitForDeployment();

  const vectorSize = 16;
  const chunkSize = 8;

  const parsedEnv = dotenv.parse(fs.readFileSync("node_modules/fhevm/gateway/.env.gateway"));
  const gatewayContractAddress = parsedEnv.GATEWAY_CONTRACT_PREDEPLOY_ADDRESS;

  const gateway = await ethers.getContractAt(
    "fhevm/gateway/GatewayContract.sol:GatewayContract",
    gatewayContractAddress,
    signer
  );

  let instance = await createFhevmInstance();

  const input1 = instance.createEncryptedInput(await faceDetection.getAddress(), signer.address);

  input1.add16(10);
  input1.add16(10);
  input1.add16(10);

  const encryptedLocation = input1.encrypt();

  await faceDetection.connect(signer).uploadImage(encryptedLocation.handles[0], encryptedLocation.handles[1], encryptedLocation.handles[2], encryptedLocation.inputProof);

});