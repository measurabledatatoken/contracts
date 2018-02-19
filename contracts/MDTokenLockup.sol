pragma solidity ^0.4.17;

import './math/SafeMath.sol';
import './token/ERC677Receiver.sol';
import './token/ERC20.sol';
import './ownership/Ownable.sol';

/**
 * @title The MDTokenLockup contract
 * @dev Lock up MDT and receive bonus
 * @author MDT Team
 */
contract MDTokenLockup is ERC677Receiver, Ownable {
    using SafeMath for uint256;

    enum LockupPeriod { THREE_MONTH, SIX_MONTH, TWELVE_MONTH }

    uint256 public constant MIN_LOCKUP_AMOUNT = 625 * 10**18; // minimum lockup aount - 625 MDT
    uint256 public constant THREE_MONTH_BONUS = 10; // 10% bonus for 3 months lockup
    uint256 public constant SIX_MONTH_BONUS = 30; // 30% bonus for 6 months lockup
    uint256 public constant TWELVE_MONTH_BONUS = 66; // 66% bonus for 12 months lockup

    uint256 public endTime;
    uint256 public totalTokensLocked;
    uint256 public totalBonusTokens;
    ERC20 public token;

    // Token Lockup for the investor
    struct Lockup {
        uint256 value;
        LockupPeriod lockupPeriod;
        uint256 endTime;
        bool withdrawn;
        uint256 withdrawnTime;
    }

    // Investor address to tokens purchased mapping during early and late bird sale
    mapping (address => uint256) public earlyLateBirdParticipantsHistory;

    // Investor address to tokens purchased mapping during private sale
    mapping (address => uint256) public privateSaleParticipantsHistory;

    // Early and late bird token lockup mapping
    mapping (address => Lockup) public earlyLateBirdTokenLockup;

    // Early and late bird token lockup participants array
    address[] public earlyLateBirdLockupParticipants;

    // Private sale token lockup mapping
    mapping (address => Lockup) public privateSaleTokenLockup;

    // Private sale token lockup participants array
    address[] public privateSaleLockupParticipants;

    // Events
    event TokensLocked(address indexed _owner, uint256 _amount, uint8 _lockupPeriod, bool _isPrivateSale);
    event TokensWithdrawn(address indexed _to, uint256 _amount, bool _isPrivateSale);
    event TokensRefunded(address indexed _to, uint256 _amount, bool _isPrivateSale);
    event BonusDeposited(address indexed _owner, uint256 _amount);
    event BonusWithdrawn(address indexed _to, uint256 _amount);

    modifier onlyDuringLockEvent {
        require(!hasEnded());
        _;
    }

    /**
    * @dev MDTokenLockup contract constructor.
    * @param _tokenAddress address The MDT contract address.
    * @param _endTime uint256 The end time of the lockup event.
    */
    function MDTokenLockup(address _tokenAddress, uint256 _endTime) public {
        require(_tokenAddress != address(0));
        require(_endTime > now);

        token = ERC20(_tokenAddress);
        endTime = _endTime;
    }

    /**
     * @dev Set early/late bird participants history. (contract owner only)
     * @param _addresses address[] Addresses that investors used to participate in early/late bird sale.
     * @param _values uint256[] Amount of tokens purchased in early/late bird sale.
     */
    function setEarlyLateBirdParticipantsHistory(address[] _addresses, uint256[] _values) public onlyOwner {
        require(_addresses.length == _values.length);

        for (uint i = 0; i < _addresses.length; i++) {
            require(_addresses[i] != address(0) && _values[i] > 0);
            earlyLateBirdParticipantsHistory[_addresses[i]] = _values[i];
        }
    }

    /**
     * @dev Set private sale participants history. (contract owner only)
     * @param _addresses address[] Addresses that investors used to participate in private sale.
     * @param _values uint256[] Amount of tokens purchased in early/late private sale.
     */
    function setPrivateSaleParticipantsHistory(address[] _addresses, uint256[] _values) public onlyOwner {
        require(_addresses.length == _values.length);

        for (uint i = 0; i < _addresses.length; i++) {
            require(_addresses[i] != address(0) && _values[i] > 0);
            privateSaleParticipantsHistory[_addresses[i]] = _values[i];
        }
    }

    /**
     * @dev Delete early/late bird participants history. (contract owner only)
     * @param _address address Address to be deleted.
     */
    function deleteEarlyLateBirdParticipantsHistory(address _address) public onlyOwner {
        require(_address != address(0));
        delete earlyLateBirdParticipantsHistory[_address];
    }

    /**
     * @dev Delete private sale participants history. (contract owner only)
     * @param _address address Address to be deleted.
     */
    function deletePrivateSaleParticipantsHistory(address _address) public onlyOwner {
        require(_address != address(0));
        delete privateSaleParticipantsHistory[_address];
    }

    /**
     * @dev Get token balance for a wallet address.
     * @param _address address Address to be queried.
     * @return the token balance of a wallet address.
     */
    function tokenBalance(address _address) public view returns (uint256) {
        return token.balanceOf(_address);
    }

    /**
     * @dev Get token balance of this contract.
     * @return the token balance of this contract.
     */
    function totalTokens() public view returns (uint256) {
        return token.balanceOf(this);
    }

    /**
     * @dev Get amount of tokens that sent accidentally to this contract.
     * @return amount of tokens that sent accidentally.
     */
    function tokensSentAccidentally() public view returns (uint256) {
        return totalTokens().sub(totalTokensLocked).sub(totalBonusTokens);
    }

    /**
     * @dev Check if the lockup event ends.
     * @return true if the lockup event ended.
     */
    function hasEnded() public view returns (bool) {
        return now > endTime;
    }

    /**
     * @dev Get addresses of early/late bird lockup participants.
     * @return addresses of early/late bird lockup participants.
     */
    function getEarlyLateBirdLockupParticipants() public view returns (address[]) {
        return earlyLateBirdLockupParticipants;
    }

    /**
     * @dev Get addresses of private sale lockup participants.
     * @return addresses of private sale lockup participants.
     */
    function getPrivateSaleLockupParticipants() public view returns (address[]) {
        return privateSaleLockupParticipants;
    }

    function getTokenLockup(address sender, bool isPrivateSale) private view returns (Lockup storage) {
        if (isPrivateSale) {
            return privateSaleTokenLockup[sender];
        } else {
            return earlyLateBirdTokenLockup[sender];
        }
    }

    function getLockupParticipants(bool isPrivateSale) private view returns (address[] storage) {
        if (isPrivateSale) {
            return privateSaleLockupParticipants;
        } else {
            return earlyLateBirdLockupParticipants;
        }
    }

    /**
     * @dev Get token lockup record.
     * @param isPrivateSale bool If it is asked the private sale record.
     * @return a tuple of token lockup record (value, lockupPeriod, endTime, withdrawn, withdrawnTime).
     */
    function getLockupRecord(bool isPrivateSale) public view returns (uint256, uint8, uint256, bool, uint256) {
        Lockup storage lockup = getTokenLockup(msg.sender, isPrivateSale);
        return (lockup.value, uint8(lockup.lockupPeriod), lockup.endTime, lockup.withdrawn, lockup.withdrawnTime);
    }

    /**
     * @dev Callback function when someone send tokens to this contract via the ERC677 contract's transferAndCall function.
     * @param _sender address The caller address.
     * @param _value uint The amount to be transferred.
     * @param _data bytes The extra data to be passed to the receiving contract.
     * @return true if it is called by the assigned token contract.
     */
    function onTokenTransfer(address _sender, uint _value, bytes _data) public onlyDuringLockEvent returns (bool success) {
        // only accept callback from assigned token contract
        if (msg.sender != address(token)) {
            return false;
        }

        require(_data.length > 0);
        lockupTokens(_sender, _value, uint8(_data[0]), false);
        return true;
    }

    function lockupTokens(address _sender, uint256 _amount, uint8 _lockupPeriod, bool lockPrivateSale) private {
        require(_sender != address(0));
        require(_lockupPeriod <= uint8(LockupPeriod.TWELVE_MONTH));
        require(_amount >= MIN_LOCKUP_AMOUNT);
        if (lockPrivateSale) {
            require(privateSaleTokenLockup[_sender].value == 0);
            require(privateSaleParticipantsHistory[_sender] > 0 && _amount <= privateSaleParticipantsHistory[_sender]);
            _lockupTokens(_sender, _amount, _lockupPeriod, privateSaleTokenLockup[_sender], lockPrivateSale);
            privateSaleLockupParticipants.push(_sender);
        } else {
            require(earlyLateBirdTokenLockup[_sender].value == 0);
            require(earlyLateBirdParticipantsHistory[_sender] > 0 && _amount <= earlyLateBirdParticipantsHistory[_sender]);
            _lockupTokens(_sender, _amount, _lockupPeriod, earlyLateBirdTokenLockup[_sender], lockPrivateSale);
            earlyLateBirdLockupParticipants.push(_sender);
        }
    }

    function _lockupTokens(address _sender, uint256 _amount, uint8 _lockupPeriod, Lockup storage lockup, bool lockPrivateSale) private {
        lockup.value = lockup.value.add(_amount);
        lockup.lockupPeriod = LockupPeriod(_lockupPeriod);
        lockup.endTime = calculateLockupEndTime(lockup.lockupPeriod);
        lockup.withdrawn = false;
        totalTokensLocked = totalTokensLocked.add(_amount);

        TokensLocked(_sender, _amount, _lockupPeriod, lockPrivateSale);
    }

    /**
     * @dev Lockup tokens. (contract owner only)
     * @dev Caller must call approve method of token contract before calling this function.
     * @param _sender address The investor address.
     * @param _tokenOwner address The token owner. (must approve the lockup contract to transfer his tokens)
     * @param _amount uint256 Amount of tokens to be locked.
     * @param _lockupPeriod uint8 The lockup period.
     * @param _lockPrivateSale bool If it is a private sale lockup.
     */
    function lockupTokensByOwner(address _sender, address _tokenOwner, uint256 _amount, uint8 _lockupPeriod, bool _lockPrivateSale) public onlyOwner {
        uint256 allowance = token.allowance(_tokenOwner, this);
        require(allowance > 0 && _amount >= MIN_LOCKUP_AMOUNT && _amount <= allowance);
        lockupTokens(_sender, _amount, _lockupPeriod, _lockPrivateSale);
        // transfer tokens to the contract only if tokens can be locked
        require(token.transferFrom(_tokenOwner, this, _amount));
    }

    /**
     * @dev Deposit bonus tokens to the contract. (contract owner only)
     * @param _tokenOwner address The token owner.
     * @param _amount uint256 Amount of bonus tokens.
     */
    function depositBonus(address _tokenOwner, uint256 _amount) public onlyOwner {
        uint256 allowance = token.allowance(_tokenOwner, this);
        require(allowance > 0 && _amount > 0 && _amount <= allowance);
        require(token.transferFrom(_tokenOwner, this, _amount));
        totalBonusTokens = totalBonusTokens.add(_amount);
        BonusDeposited(_tokenOwner, _amount);
    }

    /**
     * @dev Withdraw bonus tokens from the contract. (contract owner only)
     * @param _tokenReceiver address Wallet for receiving tokens.
     * @param _amount uint256 Amount of bonus tokens.
     */
    function withdrawBonus(address _tokenReceiver, uint256 _amount) public onlyOwner {
        require(_tokenReceiver != address(0) && _tokenReceiver != address(token) && _tokenReceiver != address(this));
        require(_amount > 0 && _amount <= totalBonusTokens);
        totalBonusTokens = totalBonusTokens.sub(_amount);
        require(token.transfer(_tokenReceiver, _amount) == true);
        BonusWithdrawn(_tokenReceiver, _amount);
    }

    /**
     * @dev Calculate token with bonus after lockup period.
     * @param _value uint256 Amount of tokens for lockup.
     * @param _lockupPeriod LockupPeriod The lockup period, which must be 0 (3 months), 1 (6 months) and 2 (12 months).
     * @return a tuple of tokens plus bonus and bonus.
     */
    function calculateTokensWithBonus(uint256 _value, LockupPeriod _lockupPeriod) public pure returns (uint256 total, uint256 bonus) {
        uint256 bonusPercent;
        if (_lockupPeriod == LockupPeriod.THREE_MONTH) {
            bonusPercent = THREE_MONTH_BONUS;
        } else if (_lockupPeriod == LockupPeriod.SIX_MONTH) {
            bonusPercent = SIX_MONTH_BONUS;
        } else if (_lockupPeriod == LockupPeriod.TWELVE_MONTH) {
            bonusPercent = TWELVE_MONTH_BONUS;
        }
        bonus = _value.mul(bonusPercent).div(100);
        total = _value.add(bonus);
    }

    /**
     * @dev Calculate lockup end date. End time is calculated based on the lockup period.
     * @dev Lockup end time = now + lockup period.
     * @param _lockupPeriod LockupPeriod The lockup period, which must be 0 (3 months), 1 (6 months) and 2 (12 months).
     * @return lockup end time.
     */
    function calculateLockupEndTime(LockupPeriod _lockupPeriod) public view returns (uint256) {
        uint256 _endTime = now;
        if (_lockupPeriod == LockupPeriod.THREE_MONTH) {
            _endTime = _endTime.add(90 days);
        } else if (_lockupPeriod == LockupPeriod.SIX_MONTH) {
            _endTime = _endTime.add(180 days);
        } else if (_lockupPeriod == LockupPeriod.TWELVE_MONTH) {
            _endTime = _endTime.add(1 years);
        }
        return _endTime;
    }

    /**
     * @dev Check if the sender can withdraw tokens.
     * @param isPrivateSale bool If it is private sale lockup.
     * @return true if the sender can withdraw tokens.
     */
    function canWithdrawTokens(bool isPrivateSale) public view returns (bool) {
        Lockup storage lockup = getTokenLockup(msg.sender, isPrivateSale);
        return lockup.value > 0 && now >= lockup.endTime && lockup.withdrawn == false;
    }

    /**
     * @dev Withdraw locked tokens with bonus. (can only be called after lockup event)
     * @param isPrivateSale bool If it is private sale lockup.
     * @return amount of tokens and bonus.
     */
    function withdrawTokens(bool isPrivateSale) public returns (uint256) {
        require(canWithdrawTokens(isPrivateSale));
        Lockup storage lockup = getTokenLockup(msg.sender, isPrivateSale);
        var (tokenWithBonus, bonus) = calculateTokensWithBonus(lockup.value, lockup.lockupPeriod);
        totalTokensLocked = totalTokensLocked.sub(lockup.value);
        totalBonusTokens = totalBonusTokens.sub(bonus);
        lockup.withdrawn = true;
        lockup.withdrawnTime = now;
        require(token.transfer(msg.sender, tokenWithBonus) == true);
        TokensWithdrawn(msg.sender, tokenWithBonus, isPrivateSale);
        return tokenWithBonus;
    }

    /**
     * @dev Refund locked tokens to investor. (contract owner only)
     * @param investor address The address of the token to transfer.
     * @param isPrivateSale bool If it is private sale lockup.
     */
    function refund(address investor, bool isPrivateSale) public onlyOwner {
        require(investor != address(0) && investor != address(token) && investor != address(this));
        Lockup storage lockup = getTokenLockup(investor, isPrivateSale);
        uint256 lockedAmount = lockup.value;
        require(lockedAmount > 0 && !lockup.withdrawn && now < lockup.endTime);
        totalTokensLocked = totalTokensLocked.sub(lockedAmount);
        // Delete address from the early and late bird lockup array
        address[] storage lockupParticipants = getLockupParticipants(isPrivateSale);
        for (uint i = 0; i < lockupParticipants.length; i++) {
            if (lockupParticipants[i] == investor) {
                delete lockupParticipants[i];
                break;
            }
        }
        if (isPrivateSale) {
            delete privateSaleTokenLockup[investor];
        } else {
            delete earlyLateBirdTokenLockup[investor];
        }
        require(token.transfer(investor, lockedAmount) == true);
        TokensRefunded(investor, lockedAmount, isPrivateSale);
    }

    /**
     * @dev Transfer to owner any tokens send by mistake to this contract. (contract owner only)
     * @param _token ERC20 The address of the token to transfer.
     * @param amount uint256 The amount to be transfered.
     */
    function emergencyERC20Drain(ERC20 _token, uint256 amount) public onlyOwner {
        _token.transfer(owner, amount);
    }
}