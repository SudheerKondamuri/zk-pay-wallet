import fs from "fs";
import path from "path";
import hre from "hardhat";

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  console.log("Deploying contracts with account:", deployer.address);

  // Deploy StubZKVerifier
  const StubZKVerifier = await hre.ethers.getContractFactory("StubZKVerifier");
  const stubVerifier = await StubZKVerifier.deploy();
  await stubVerifier.waitForDeployment();
  const verifierAddress = await stubVerifier.getAddress();
  console.log("StubZKVerifier deployed to:", verifierAddress);

  // Deploy ZKRollupPayments
  const ZKRollupPayments = await hre.ethers.getContractFactory("ZKRollupPayments");
  const rollup = await ZKRollupPayments.deploy(verifierAddress);
  await rollup.waitForDeployment();
  const rollupAddress = await rollup.getAddress();
  console.log("ZKRollupPayments deployed to:", rollupAddress);

  // Write deployments/addresses.json
  const deploymentsDir = path.join(process.cwd(), "deployments");
  if (!fs.existsSync(deploymentsDir)) {
    fs.mkdirSync(deploymentsDir, { recursive: true });
  }

  const addresses = {
    network: "localhost",
    chainId: hre.network.config.chainId || 31337,
    rpcUrl: "http://hardhat:8545", // As specified in instructions for Docker internal routing
    ZKRollupPayments: rollupAddress,
    StubZKVerifier: verifierAddress,
    deployedAt: new Date().toISOString()
  };

  fs.writeFileSync(
    path.join(deploymentsDir, "addresses.json"),
    JSON.stringify(addresses, null, 2)
  );
  console.log("Deployment addresses written to deployments/addresses.json");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
