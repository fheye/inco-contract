import { task } from "hardhat/config";
import type { TaskArguments } from "hardhat/types";

task("task:deploy").setAction(async function (taskArguments: TaskArguments, { ethers }) {
  const signers = await ethers.getSigners();
  const faceDetectionFactory = await ethers.getContractFactory("FaceDetection");
  const faceDetection = await faceDetectionFactory.connect(signers[0]).deploy();
  await faceDetection.waitForDeployment();
  console.log("FaceDetection deployed to: ", await faceDetection.getAddress());

  
});
