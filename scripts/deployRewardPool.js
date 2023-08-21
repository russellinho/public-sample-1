async function main() {
    const RewardPoolContract = await hre.ethers.getContractFactory("RewardPool");
    const rewardPoolDeployed = await RewardPoolContract.deploy('0xFF2F30d0f089f9B5FC1AbBf8b543169Df18A0c02'); // add power switch contract address
    await rewardPoolDeployed.deployed();
  
    console.log("Reward Pool Contract deployed to:", rewardPoolDeployed.address);
  }
  
  main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });