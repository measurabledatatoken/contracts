pragma solidity ^0.5.10;

import './math/SafeMath.sol';
import './token/ERC677Receiver.sol';
import './token/ERC20.sol';
import './ownership/Ownable.sol';

/**
 * @title The MDTDataReward contract
 * @dev Share data and receive MDT rewards
 * @author MDT Team
 */
contract MDTDataReward is ERC677Receiver, Ownable {
    using SafeMath for uint256;

    // Data rewards record
    struct Reward {
        uint256 claimableValue;
        uint256 totalTokensClaimed;
        uint256 lastWithdrawnTime;
        bool enabled;
    }

    ERC20 public token;
    uint256 public totalTokens;
    uint256 public totalTokensClaimed;
    bool public isSuspended;

    mapping (address => Reward) public dataRewards;
    address[] public boundAddresses;

    // Events
    event TokensDeposited(address indexed _owner, uint256 _amount);
    event TokensWithdrawn(address indexed _to, uint256 _amount);
    event RewardsDelivered(address indexed _to, uint256 _amount);
    event RewardsClaimed(address indexed _to, uint256 _amount);
    event RewardsCanceled(address indexed _to, uint256 _amount);
    event RewardsTransferred(address indexed _from, address indexed _to, uint256 _amount);

    modifier onlyActive {
        require(!isSuspended, "contract is suspended");
        _;
    }

    /// @dev Reverts if address is 0x0 or this token address
    modifier validRecipient(address _recipient) {
        require(_recipient != address(0) && _recipient != address(this), "recipient cannot be zero address and the contract");
        _;
    }

    /**
    * @dev MDTDataReward contract constructor.
    * @param _tokenAddress address The MDT contract address.
    */
    constructor(address _tokenAddress) public {
        require(_tokenAddress != address(0), "token address cannot be zero");

        token = ERC20(_tokenAddress);
    }

    function onTokenTransfer(address _sender, uint _value, bytes memory /*_data*/) public returns (bool success) {
        // only accept callback from assigned token contract
        if (msg.sender != address(token)) {
            return false;
        }

        // only contract owner can send tokens to this reward contract
        require(_sender == owner, "only contract owner is allowed to send tokens to this contract");

        // update available rewards
        totalTokens = totalTokens.add(_value);
        emit TokensDeposited(_sender, _value);
        return true;
    }

    /**
     * @dev Set data rewards to enabled or disabled for a wallet address. (contract owner only)
     * @param _address address Wallet address.
     * @param bool true to set the rewards to available.
     */
    function setRewardsEnabled(address _address, bool _isEnabled) public onlyOwner {
        Reward storage reward = dataRewards[_address];
        if (reward.enabled == true && _isEnabled == false) {
            for (uint i = 0; i < boundAddresses.length; i++) {
                if (boundAddresses[i] == _address) {
                    delete boundAddresses[i];
                    break;
                }
            }
            reward.enabled = false;
        } else if (reward.enabled == false && _isEnabled == true) {
            boundAddresses.push(_address);
            reward.enabled = true;
        }
    }

    /**
     * @dev Deposit tokens to the contract. (contract owner only)
     * @param _tokenOwner address The token owner.
     * @param _amount uint256 Amount of tokens.
     */
    function depositTokens(address _tokenOwner, uint256 _amount) public onlyOwner {
        uint256 allowance = token.allowance(_tokenOwner, address(this));
        require(allowance > 0 && _amount > 0 && _amount <= allowance, "invalid allowance or amount");
        require(token.transferFrom(_tokenOwner, address(this), _amount), "failed to transfer tokens to this contract");
        totalTokens = totalTokens.add(_amount);
        emit TokensDeposited(_tokenOwner, _amount);
    }

    /**
     * @dev Deliver data rewards to users. (contract owner only)
     * @param _addresses address[] Addresses that MDT users binded to receive data rewards.
     * @param _values uint256[] Amount of tokens earned.
     */
    function deliverRewards(address[] memory _addresses, uint256[] memory _values) public onlyOwner {
        require(_addresses.length == _values.length, "length of addresses array must be equal to values array");

        for (uint i = 0; i < _addresses.length; i++) {
            require(_addresses[i] != address(0) && _values[i] > 0, "address cannot be zero and value must be greater than zero");
            Reward storage reward = dataRewards[_addresses[i]];
            reward.claimableValue = reward.claimableValue.add(_values[i]);
            if (reward.enabled == false) {
                boundAddresses.push(_addresses[i]);
                reward.enabled = true;
            }
            emit RewardsDelivered(_addresses[i], _values[i]);
        }
    }

    /**
     * @dev Cancel expired data rewards if users don't claim within a certain period. (contract owner only)
     * @param _addresses address[] Addressses that have expired data rewards.
     * @param _values uint256[] Amount of tokens to cancel from an address.
     */
    function cancelRewards(address[] memory _addresses, uint256[] memory _values) public onlyOwner {
        require(_addresses.length == _values.length, "length of addresses array must be equal to values array");

        for (uint i = 0; i < _addresses.length; i++) {
            require(_addresses[i] != address(0) && _values[i] > 0, "address cannot be zero and value must be greater than zero");
            Reward storage reward = dataRewards[_addresses[i]];
            require(reward.claimableValue > 0 && reward.claimableValue <= _values[i],
                "claimable value must be greater than zero and smaller than or equal to value");
            reward.claimableValue = reward.claimableValue.sub(_values[i]);
            emit RewardsCanceled(_addresses[i], _values[i]);
        }
    }

    /**
     * @dev Transfer tokens between wallets, used when user binds the account to a different wallet address. (contract owner only)
     * @param _fromAddress address The wallet address to transfer tokens from
     * @param _toAddress address The wwallet address to transfer tokens to
     * @param _amount amount of tokens to be transfered
     */
    function transferRewards(address _fromAddress, address _toAddress, uint256 _amount)
        public
        onlyOwner
        validRecipient(_fromAddress)
        validRecipient(_toAddress)
    {
        require(_amount > 0 && _fromAddress != _toAddress, "amount must be greater than zero and from address must not equal to to address");
        Reward storage fromReward = dataRewards[_fromAddress];
        Reward storage toReward = dataRewards[_toAddress];
        require(fromReward.claimableValue > 0 && _amount <= fromReward.claimableValue, "invalid amount to transfer from an address");
        fromReward.claimableValue = fromReward.claimableValue.sub(_amount);
        toReward.claimableValue = toReward.claimableValue.add(_amount);
        if (toReward.enabled == false) {
            boundAddresses.push(_toAddress);
            toReward.enabled = true;
        }

        emit RewardsTransferred(_fromAddress, _toAddress, _amount);
    }

    /**
     * @dev claim rewards earned/
     * @return amount of tokens claimed.
     */
    function claimRewards() public returns (uint256) {
        require(canClaimRewards(), "reward is not found or unable to claim now");
        Reward storage reward = dataRewards[msg.sender];
        uint256 value = reward.claimableValue;
        reward.claimableValue = 0;
        reward.totalTokensClaimed = reward.totalTokensClaimed.add(value);
        reward.lastWithdrawnTime = now;
        totalTokensClaimed = totalTokensClaimed.add(value);
        totalTokens = totalTokens.sub(value);
        require(token.transfer(msg.sender, value) == true, "failed to transfer tokens");
        emit RewardsClaimed(msg.sender, value);
        return value;
    }

    /**
     * @dev Withdraw tokens from the contract. (contract owner only)
     * @param _tokenReceiver address Wallet for receiving tokens.
     * @param _amount uint256 Amount of tokens.
     */
    function withdrawTokens(address _tokenReceiver, uint256 _amount)
        public
        onlyOwner
        validRecipient(_tokenReceiver)
    {
        require(_amount > 0 && _amount <= totalTokens, "amount must be greater than zero and smaller than or equal to total tokens deposited");
        totalTokens = totalTokens.sub(_amount);
        require(token.transfer(_tokenReceiver, _amount) == true, "failed to transfer tokens");
        emit TokensWithdrawn(_tokenReceiver, _amount);
    }

    /**
     * @dev Suspend the data reward contract. (contract owner only)
     */
    function suspend() public onlyOwner {
        if (isSuspended == true) {
            return;
        }
        isSuspended = true;
    }

    /**
     * @dev Resume the data reward contract. (contract owner only)
     */
    function resume() public onlyOwner {
        if (isSuspended == false) {
            return;
        }
        isSuspended = false;
    }

    /**
     * @dev Transfer to owner any tokens send by mistake to this contract. (contract owner only)
     * @param _token ERC20 The address of the token to transfer.
     * @param amount uint256 The amount to be transferred.
     */
    function emergencyERC20Drain(ERC20 _token, uint256 amount) public onlyOwner {
        _token.transfer(owner, amount);
    }

    /**
     * @dev Get token balance of a wallet address.
     * @param _address address Address to be queried.
     * @return the token balance of a wallet address.
     */
    function tokenBalanceAtAddress(address _address) public view returns (uint256) {
        return token.balanceOf(_address);
    }

    /**
     * @dev Get token balance of this contract.
     * @return the token balance of this contract.
     */
    function contractTokenBalance() public view returns (uint256) {
        return token.balanceOf(address(this));
    }

    /**
     * @dev Get amount of tokens that sent accidentally to this contract.
     * @return amount of tokens that sent accidentally.
     */
    function tokensSentAccidentally() public view returns (uint256) {
        return contractTokenBalance().sub(totalTokens);
    }

    /**
     * @dev Get total tokens claimed for the caller address.
     * @return amount of tokens claimed.
     */
    function getTotalTokensClaimed() public view returns (uint256) {
        return dataRewards[msg.sender].totalTokensClaimed;
    }

    /**
     * @dev Get amount of claimable tokens for the caller address.
     * @return amount of claimable tokens.
     */
    function getClaimableValue() public view returns (uint256) {
        return dataRewards[msg.sender].claimableValue;
    }

    /**
     * @dev Get bound addresses.
     * @return bound addresses.
     */
    function getBoundAddresses() public view returns (address[] memory) {
        return boundAddresses;
    }

    /**
     * @dev Check if the caller address has claimable rewards.
     * @return true if the caller has claimable rewards.
     */
    function canClaimRewards() public view returns (bool) {
        if (isSuspended) {
            return false;
        }
        Reward storage reward = dataRewards[msg.sender];
        return reward.enabled && reward.claimableValue > 0;
    }

    /**
     * @dev Get rewards for the caller.
     * @return (claimableValue, totalTokensClaimed, lastWithdrawnTime, enabled)
     */
    function getReward() public view returns (uint256, uint256, uint256, bool) {
        Reward storage reward = dataRewards[msg.sender];
        return (reward.claimableValue, reward.totalTokensClaimed, reward.lastWithdrawnTime, reward.enabled);
    }

    /**
     * @dev rewards for address. (contract owner only)
     * @return (claimableValue, totalTokensClaimed, lastWithdrawnTime, enabled)
     */
    function getRewardForAddress(address _address) public onlyOwner view returns (uint256, uint256, uint256, bool) {
        Reward storage reward = dataRewards[_address];
        return (reward.claimableValue, reward.totalTokensClaimed, reward.lastWithdrawnTime, reward.enabled);
    }
}