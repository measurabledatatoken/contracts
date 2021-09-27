AppError = {
  METAMASK_NOT_INSTALLED: 0,
  METAMASK_LOCKED: 1,
  FAILED_LOADING_CONTRACT: 2
};

LockupPeriod = {
  THREE_MONTH: '0x00',
  SIX_MONTH: '0x01',
  ONE_YEAR: '0x02'
};

function CustomException(message, errorType) {
  this.message = message;
  this.errorType = errorType;
  // Use V8's native method if available, otherwise fallback
  if ("captureStackTrace" in Error)
    Error.captureStackTrace(this, CustomException);
  else
    this.stack = (new Error()).stack;
}

CustomException.prototype = Object.create(Error.prototype);
CustomException.prototype.name = "CustomException";
CustomException.prototype.constructor = CustomException;

Date.prototype.getUnixTime = function () {
  return this.getTime() / 1000 | 0;
};
Date.prototype.addDays = function (numberOfDays) {
  return new Date(this.getTime() + (numberOfDays * 24 * 60 * 60 * 1000));
};

window.TokenLockupApp = {
  tokenContractAddress: null,
  lockupContractAddress: null,
  tokenContractAbiUrl: null,
  lockupContractAbiUrl: null,
  TokenContract: null,
  LockupContract: null,
  tokenContract: null,
  lockupContract: null,
  account: null,
  tokenBalance: 0,

  // contract state
  earlyLateBirdLockupRecord: null,
  privateSaleLockupRecord: null,
  canWithdrawEarlyLateBirdTokens: false,
  canWithdrawPrivateSaleTokens: false,
  maxLockupAmount: 0,
  eventEnded: false,

  init: function (tokenContractAddress, tokenContractAbiUrl, lockupContractAddress, lockupContractAbiUrl) {
    this.tokenContractAddress = tokenContractAddress;
    this.tokenContractAbiUrl = tokenContractAbiUrl;
    this.lockupContractAddress = lockupContractAddress;
    this.lockupContractAbiUrl = lockupContractAbiUrl;

    // bind functions to this so they run properly in callback
    this.initWeb3 = this.initWeb3.bind(this);
    this.loadAccount = this.loadAccount.bind(this);
    this.initTokenLockupContract = this.initTokenLockupContract.bind(this);
    this.initMDTokenContract = this.initMDTokenContract.bind(this);
    this.getTokenContractAddress = this.getTokenContractAddress.bind(this);
    this.getEventEnded = this.getEventEnded.bind(this);
    this.getLockupRecord = this.getLockupRecord.bind(this);
    this.getMaximumLockupAmount = this.getMaximumLockupAmount.bind(this);
    this.getTokenBalance = this.getTokenBalance.bind(this);
    this.getAvailableLockupAmount = this.getAvailableLockupAmount.bind(this);
    this.canLockTokens = this.canLockTokens.bind(this);
    this.lockupTokens = this.lockupTokens.bind(this);
    this.getCanWithdrawTokens = this.getCanWithdrawTokens.bind(this);
    this.withdrawTokens = this.withdrawTokens.bind(this);
    this.hasLockedTokens = this.hasLockedTokens.bind(this);
    this.canWithdrawTokens = this.canWithdrawTokens.bind(this);
    this.loadContractState = this.loadContractState.bind(this);

    return this.initWeb3()
      .then(this.loadAccount)
      .then(this.initTokenLockupContract)
      // .then(this.getTokenContractAddress)
      .then(this.initMDTokenContract)
      .then(this.getTokenBalance)
      .then(this.loadContractState);
  },

  initWeb3: function () {
    var self = this;
    return new Promise(function (resolve, reject) {
      if (typeof ethereum !== 'undefined') {
        window.web3 = new Web3(ethereum);
        // Asks the user for permission to connect to the metamask account.
        ethereum.request({ method: 'eth_requestAccounts' })
          .then(function (accounts) {
            var account = accounts[0];
            if (account === undefined) {
              reject(self.formatError('Account not found, please unlock your Metamask account', AppError.METAMASK_LOCKED));
            } else {
              resolve(web3);
            }
          })
          .catch(function (reason) {
            // Handle error. Likely the user rejected the login.
            reject(self.formatError('Account not found, please unlock your Metamask account', AppError.METAMASK_LOCKED));
          })
      } else if (typeof web3 !== 'undefined') {
        window.web3 = new Web3(web3.currentProvider);
        resolve(web3);
      } else {
        reject(self.formatError('Probably, metamask is not installed!', AppError.METAMASK_NOT_INSTALLED));
      }
    });
  },

  initTokenLockupContract: function () {
    var self = this;
    return new Promise(function (resolve, reject) {
      $.getJSON(self.lockupContractAbiUrl, function (abi) {
        try {
          // Get the necessary contract artifact file and instantiate it with truffle-contract.
          self.LockupContract = TruffleContract(abi);

          // Set the provider for our contract.
          self.LockupContract.setProvider(web3.currentProvider);

          // Load the lockup contract.
          self.LockupContract.at(self.lockupContractAddress).then(function (instance) {
            self.lockupContract = instance;
            console.log('Lockup contract loaded successfully.');
            resolve(instance);
          }).catch(function (err) {
            reject(self.formatError(err, AppError.FAILED_LOADING_CONTRACT));
          });
        } catch (ex) {
          reject(self.formatError('Error in accessing token lockup contract! ' + ex.valueOf(), AppError.FAILED_LOADING_CONTRACT));
        }
      }).fail(function () {
        reject(self.formatError('Failed loading token lockup contract!'));
      });
    });
  },

  initMDTokenContract: function () {
    var self = this;
    return new Promise(function (resolve, reject) {
      $.getJSON(self.tokenContractAbiUrl, function (abi) {
        try {
          // Get the necessary contract artifact file and instantiate it with truffle-contract.
          self.TokenContract = TruffleContract(abi);

          // Set the provider for our contract.
          self.TokenContract.setProvider(web3.currentProvider);

          // Load the token contract.
          self.TokenContract.at(self.tokenContractAddress).then(function (instance) {
            self.tokenContract = instance;
            console.log('Token contract loaded successfully.');
            resolve(instance);
          }).catch(function (err) {
            reject(self.formatError(err, AppError.FAILED_LOADING_CONTRACT));
          });
        } catch (ex) {
          reject(self.formatError('Error in accessing token contract! ' + ex.valueOf(), AppError.FAILED_LOADING_CONTRACT));
        }
      }).fail(function () {
        reject(self.formatError('Failed loading token contract!'));
      });
    });
  },

  loadAccount: function () {
    var self = this;
    return new Promise(function (resolve, reject) {
      web3.eth.getAccounts(function (error, accounts) {
        console.log(error, accounts);
        var account = accounts[0];
        if (account === undefined) {
          reject(self.formatError('Account not found, please unlock your Metamask account',
            AppError.METAMASK_LOCKED));
        } else {
          self.account = account.trim();
          // console.log('Account is ' + account);
          resolve(account);
        }
      });
    });
  },

  loadContractState: function () {
    var self = this;
    return Promise.all([
      this.getEventEnded(),
      this.getLockupRecord(true),
      this.getLockupRecord(false),
      this.getMaximumLockupAmount(),
    ]).then(function () {
      if (self.eventEnded) {
        var promises = [];
        if (self.privateSaleLockupRecord.value > 0 &&
          !self.privateSaleLockupRecord.withdrawn) {
          promises.push(self.getCanWithdrawTokens(true));
        }
        if (self.earlyLateBirdLockupRecord.value > 0 &&
          !self.earlyLateBirdLockupRecord.withdrawn) {
          promises.push(self.getCanWithdrawTokens(false));
        }
        return Promise.all(promises);
      }
    });
  },

  getTokenContractAddress: function () {
    var self = this;
    return this.lockupContract.token.call().then(function (address) {
      self.tokenContractAddress = address;
      // console.log('token contract address:', address);
      return address;
    });
  },

  getEventEnded: function () {
    var self = this;
    return this.lockupContract.hasEnded.call().then(function (eventEnded) {
      self.eventEnded = eventEnded;
      // console.log('event ended:', eventEnded);
      return eventEnded;
    });
  },

  getLockupRecord: function (isPrivateSale) {
    var self = this;
    return this.lockupContract.getLockupRecord.call(isPrivateSale).then(function (record) {
      var parsedRecord = self._convertLockupRecord(record);
      // console.log('lockup record:', parsedRecord);
      if (isPrivateSale) {
        self.privateSaleLockupRecord = parsedRecord;
      } else {
        self.earlyLateBirdLockupRecord = parsedRecord;
      }
      return parsedRecord;
    });
  },

  _convertLockupRecord: function (record) {
    var value = parseFloat(web3.fromWei(record[0].toString(10)));
    var lockupPeriod;
    switch (parseInt(record[1])) {
      case 0:
        lockupPeriod = LockupPeriod.THREE_MONTH;
        break;
      case 1:
        lockupPeriod = LockupPeriod.SIX_MONTH;
        break;
      case 2:
        lockupPeriod = LockupPeriod.ONE_YEAR;
        break;
    }
    var endTime = parseInt(record[2]) > 0 ? new Date(parseInt(record[2]) * 1000) : null;
    var withdrawn = record[3];
    var withdrawnTime = parseInt(record[4]) > 0 ? new Date(parseInt(record[4]) * 1000) : null;
    return {
      value: value,
      lockupPeriod: lockupPeriod,
      endTime: endTime,
      withdrawn: withdrawn,
      withdrawnTime: withdrawnTime
    };
  },

  getMaximumLockupAmount: function () {
    var self = this;
    return this.lockupContract.earlyLateBirdParticipantsHistory.call(this.account).then(function (purchasedAmount) {
      // Since the returned MDT amount is in smallest unit, we need to convert it to a complete MDT token
      self.maxLockupAmount = parseFloat(web3.fromWei(purchasedAmount.toString(10)));
      // console.log('maximum lockup amount:', self.maxLockupAmount);
      return self.maxLockupAmount;
    });
  },

  getTokenBalance: function () {
    var self = this;
    return this.tokenContract.balanceOf.call(this.account).then(function (balance) {
      self.tokenBalance = parseFloat(web3.fromWei(balance.toString(10)));
      // console.log(self.tokenBalance);
      return self.tokenBalance;
    });
  },

  getAvailableLockupAmount: function () {
    return Math.min(this.maxLockupAmount, this.tokenBalance);
  },

  canLockTokens: function () {
    return !this.eventEnded && this.maxLockupAmount > 0 &&
      (this.earlyLateBirdLockupRecord === null || this.earlyLateBirdLockupRecord.value === 0);
  },

  lockupTokens: function (amount, lockupPeriod) {
    var self = this;
    return this.tokenContract.transferAndCall(this.lockupContractAddress, amount, lockupPeriod, {
        from: this.account,
        gas: 250000
      })
      .then(function (tx) {
        // console.log(tx);
        if (tx.receipt.status === '0x1') {
          var record = [amount, parseInt(lockupPeriod), new Date().addDays(parseInt(lockupPeriod) === 2 ? 365 : (parseInt(lockupPeriod) + 1) * 90).getUnixTime(), false, 0];
          self.earlyLateBirdLockupRecord = self._convertLockupRecord(record);
          return true;
        } else {
          return false;
        }
      });
  },

  getCanWithdrawTokens: function (isPrivateSale) {
    var self = this;
    return this.lockupContract.canWithdrawTokens.call(isPrivateSale).then(function (canWithdraw) {
      if (isPrivateSale) {
        self.canWithdrawPrivateSaleTokens = canWithdraw;
      } else {
        self.canWithdrawEarlyLateBirdTokens = canWithdraw;
      }
      // console.log('can withdraw ' + (isPrivateSale ? 'private sale tokens:' : 'early/late tokens:'), canWithdraw);
      return canWithdraw;
    });
  },

  withdrawTokens: function (isPrivateSale) {
    var self = this;
    return this.lockupContract.withdrawTokens(isPrivateSale, {
        from: this.account,
        gas: 200000
      })
      .then(function (tx) {
        // console.log(tx);
        if (tx.receipt.status === '0x1') {
          if (isPrivateSale) {
            self.canWithdrawPrivateSaleTokens = false;
            self.privateSaleLockupRecord.withdrawn = true;
            self.privateSaleLockupRecord.withdrawnTime = new Date();
          } else {
            self.canWithdrawEarlyLateBirdTokens = false;
            self.earlyLateBirdLockupRecord.withdrawn = true;
            self.earlyLateBirdLockupRecord.withdrawnTime = new Date();
          }
          return {
            success: true,
            delay: false
          };
        } else {
          return {
            success: false,
            delay: false
          };
        }
      });
  },

  hasLockedTokens: function (isPrivateSale) {
    if (isPrivateSale) {
      return this.privateSaleLockupRecord && this.privateSaleLockupRecord.value > 0;
    } else {
      return this.earlyLateBirdLockupRecord && this.earlyLateBirdLockupRecord.value > 0;
    }
  },

  canWithdrawTokens: function (isPrivateSale) {
    return isPrivateSale ? this.canWithdrawPrivateSaleTokens : this.canWithdrawEarlyLateBirdTokens;
  },

  formatError: function (message, errorType) {
    var err = new Error(message);
    if (typeof (errorType) === 'number') {
      err.type = errorType;
    }
    return err;
  }
};