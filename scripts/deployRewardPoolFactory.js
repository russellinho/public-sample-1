async function main() {
    const RewardPoolFactoryContract = await hre.ethers.getContractFactory("RewardPoolFactory");
    const rewardPoolFactoryDeployed = await RewardPoolFactoryContract.deploy();
    await rewardPoolFactoryDeployed.deployed();
    console.log("Reward Pool Factory Contract deployed to: " + rewardPoolFactoryDeployed.address);
  }
  
  main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });