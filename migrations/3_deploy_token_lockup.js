const MDTokenLockup = artifacts.require('./MDTokenLockup.sol');
const MDTokenLockupTest = artifacts.require('./MDTokenLockupTest.sol');

Date.prototype.getUnixTime = function() { return this.getTime()/1000|0; };
Date.prototype.addDays = function(numberOfDays) {
  return new Date(this.getTime() + (numberOfDays * 24 * 60 * 60 * 1000));
};

module.exports = function(deployer, network, accounts) {
  if (network === 'mainnetInfura') {
    const tokenAddress = '0x814e0908b12a99fecf5bc101bb5d0b8b5cdf7d26';
    const start = new Date('2018-02-06T07:00Z');
    const end = start.addDays(7);
    const endTime = end.getUnixTime();

    return deployer.deploy(MDTokenLockup, tokenAddress, endTime, {'gas': 3712388}).then(() => {
      console.log('Deployed MDTokenLockup address is ' + MDTokenLockup.address);
    });
  } else if (network === 'ropstenInfura') {
    const tokenAddress = '0xe3e692009828a9d44112ffac9aa62d882be3acbe';
    const start = new Date();
    const end = start.addDays(7);
    const endTime = end.getUnixTime();

    return deployer.deploy(MDTokenLockupTest, tokenAddress, endTime, true, {'gas': 3712388}).then(() => {
      console.log('Deployed MDTokenLockupTest address is ' + MDTokenLockupTest.address);
    });
  }
};