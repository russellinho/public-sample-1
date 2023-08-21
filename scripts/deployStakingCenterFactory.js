async function main() {
    const StakingCenterFactoryContract = await hre.ethers.getContractFactory("StakingCenterFactory");
    const stakingCenterFactoryDeployed = await StakingCenterFactoryContract.deploy();
    await stakingCenterFactoryDeployed.deployed();
    console.log("Staking Center Factory Contract deployed to: " + stakingCenterFactoryDeployed.address);
  }
  
  main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });