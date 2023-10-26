var ERC1410Token = artifacts.require("./ERC1410/examples/ERC1410Token.sol");

module.exports = function(deployer) {
  deployer.deploy(ERC1410Token,"Frederic2","FRED2");
};
