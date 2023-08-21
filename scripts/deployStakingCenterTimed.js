async function main() {
    const StakingCenterContract = await hre.ethers.getContractFactory("StakingCenterTimed");
    // address ownerAddress,
    // address rewardPoolFactory,
    // address powerSwitchFactory,
    // address vaultFactory,
    // address stakingToken,
    // address rewardToken,
    // uint256 lockDuration
    const stakingCenterDeployed = await hre.upgrades.deployProxy(StakingCenterContract, ['0x5e3e6d634142DCEE6b80Ba36Ef75739dac4b894B', '0xe4e8BeA4685b4c06D8B59cf82e37D15e71899592', '0x10c0CbC3e18D1E3B44e94E496575143908B12988', '0xd20079fd9ad2436737767ac3Ed374B4046d88237', '0xca16e0C254c479db08E6a1c4ED5Fe9FcbD7fDfe5', '0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174', 31540000], {
      unsafeAllowCustomTypes: true,
    });
    await stakingCenterDeployed.deployed();
  
    console.log("Staking Center Timed deployed to:", stakingCenterDeployed.address);
  }
  
  main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });