async function main() {
    const PowerSwitchContract = await hre.ethers.getContractFactory("PowerSwitch");
    const powerSwitchDeployed = await PowerSwitchContract.deploy('0x41be1Fa064BCC610CEEFA698890032beA46c6ceB'); // add power switch owner address
    await powerSwitchDeployed.deployed();
  
    console.log("Power Switch deployed to:", powerSwitchDeployed.address);
  }
  
  main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });