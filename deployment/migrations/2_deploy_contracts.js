var mainChainGateway = artifacts.require("./MainChainGateway.sol");
var config = require("../tronbox-config.js");

module.exports = function(deployer) {
  // deployer.deploy(MyContract);
  deployer.deploy(mainChainGateway, config.OracleAddress);
};
