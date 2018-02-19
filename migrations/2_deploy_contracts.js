const MDToken = artifacts.require('./MDToken.sol');
const MDTokenBank = artifacts.require('./MDTokenBank.sol');

module.exports = function(deployer, network, accounts) {
  // deployer.deploy(SafeMath);
  // deployer.deploy(Ownable);

  // deployer.link(Ownable, MDToken);
  // deployer.link(SafeMath, MDToken);
  // deployer.deploy(MDToken);

  const owner = accounts[0];
  if (network === 'mainnetInfura') {
    const tokenSaleAddress = '0x4b9B85bfEC31F8bD5b183339Cb155f3D8DE114F1';
    const mdtTeamAddress = '0x135338c6033cba64ddff14a06e74c9a15e9f93f5';
    const userGrowthAddress = '0x446c3c34baf72d1f016e52263d16a45f13b9b128';
    const investorsAddress = '0xeb9821605641389c4c29da5a6b9d94d108c47941';
    const mdtFoundationAddress = '0x818cf9a5a26c5164800016c77c90a70c3d6ac71a';
    const presaleAmount = 150000000e18;
    const earlyBirdAmount = 150000000e18;

    return deployer.deploy(MDToken, tokenSaleAddress, mdtTeamAddress, userGrowthAddress, investorsAddress,
      mdtFoundationAddress, presaleAmount, earlyBirdAmount, {'gas': 3712388}).then(() => {
        console.log('Deployed MDToken address is ' + MDToken.address);
    });
  } else {
    const tokenSaleAddress = '0x12d514f358485B3Cc3e955703C0761e44d23cB99';
    const mdtTeamAddress = '0xbe976f845557cda5589732c49b3c806e95f1ffcc';//'0x3e8f2DE87Bb864c2856697AF8B99771FdC5D1985';
    const userGrowthAddress = '0xC1fAfa96eB7FDb9135dBB988551eE25f154e8E6a';
    const investorsAddress = '0x8680eb5c6f998b3C9A13225CbDC52A034CD2ab44';
    const mdtFoundationAddress = '0xfcC5b2c0b3d0a97fa26309AD5e2262bd8aF20a5D';
    const presaleAmount = 150000000e18;
    const earlyBirdAmount = 150000000e18;

    return deployer.deploy(MDToken, tokenSaleAddress, mdtTeamAddress, userGrowthAddress, investorsAddress,
      mdtFoundationAddress, presaleAmount, earlyBirdAmount, {'gas': 3712388}).then(() => {
        console.log('Deployed MDToken address is ' + MDToken.address);
        // deploy MDTokenBank for testing ERC677Receiver function
        return deployer.deploy(MDTokenBank, MDToken.address, 97, {'gas': 2712388}).then(() => {
          console.log('Deployed MDTokenBank address is ' + MDTokenBank.address);
        });
    });
  }
};
