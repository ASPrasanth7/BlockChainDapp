var Migrations = artifacts.require("./NewGame.sol");

module.exports = function(deployer) {
  deployer.deploy(Migrations);
};
