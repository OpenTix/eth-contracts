const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

const TokenModule = buildModule("VenueMintModule", (m) => {
  const token = m.contract("VenueMint");

  return { token };
});

module.exports = TokenModule;