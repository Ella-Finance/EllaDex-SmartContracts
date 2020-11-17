var EllaExchangeService = artifacts.require("./EllaExchangeService.sol");

module.exports = async (deployer) => {
  await deployer.deploy(
    EllaExchangeService,
    "0x",
    "0x",
    true,
    "0x",
    "0x"
  );
};
