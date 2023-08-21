async function main() {
  const StakingCenterContract = await hre.ethers.getContractFactory("StakingCenterTimed");

  // Place the address of your proxy here!
  const proxyAddress = "0x04733F39c69B556A44182887F91Ee4541999D026";

  const upgraded = await hre.upgrades.upgradeProxy(proxyAddress, StakingCenterContract);

  // console.log("Proxy updated: ",upgraded);
  console.log("Proxy updated.");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });