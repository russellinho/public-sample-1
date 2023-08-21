async function main() {
    const VaultFactoryContract = await hre.ethers.getContractFactory("VaultFactory");
    const vaultFactoryDeployed = await VaultFactoryContract.deploy('0x4423DC6d914c68B67a5Ca6299E3740894C0F5d9c');
    await vaultFactoryDeployed.deployed();
    console.log("Vault Factory Contract deployed to: " + vaultFactoryDeployed.address);
  }
  
  main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });