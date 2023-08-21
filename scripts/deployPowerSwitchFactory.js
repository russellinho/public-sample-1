async function main() {
    const PowerSwitchFactoryContract = await hre.ethers.getContractFactory("PowerSwitchFactory");
    const powerSwitchFactoryDeployed = await PowerSwitchFactoryContract.deploy();
    await powerSwitchFactoryDeployed.deployed();
    console.log("Power Switch Factory Contract deployed to: " + powerSwitchFactoryDeployed.address);
  }
  
  main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });