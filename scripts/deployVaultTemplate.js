async function main() {
    const VaultContract = await hre.ethers.getContractFactory("Vault");
    const vaultDeployed = await VaultContract.deploy();
  
    await vaultDeployed.deployed();
  
    console.log("Vault Contract deployed to:", vaultDeployed.address);
  }
  
  main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });