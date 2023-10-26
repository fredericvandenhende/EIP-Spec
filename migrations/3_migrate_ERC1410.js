var ERC1410Standard = artifacts.require("./ERC1410/ERC1410Standard.sol");

module.exports = function(deployer) {
  deployer.deploy(ERC1410Standard);
};
