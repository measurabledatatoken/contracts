pragma solidity ^0.4.17;

import './math/SafeMath.sol';
import './token/ERC677Token.sol';
import './token/StandardToken.sol';
import './ownership/Ownable.sol';

/**
 * @title The MDToken contract
 * @dev The MDT Token contract
 * @author MDT Team
 */
contract MDToken is StandardToken, ERC677Token, Ownable {
    using SafeMath for uint256;

    // Token metadata
    string public constant name = "Measurable Data Token";
    string public constant symbol = "MDT";
    uint256 public constant decimals = 18;
    uint256 public constant maxSupply = 10 * (10**8) * (10**decimals); // 1 billion MDT

    // 240 million MDT reserved for MDT team (24%)
    uint256 public constant TEAM_TOKENS_RESERVED = 240 * (10**6) * (10**decimals);

    // 150 million MDT reserved for user growth (15%)
    uint256 public constant USER_GROWTH_TOKENS_RESERVED = 150 * (10**6) * (10**decimals);

    // 110 million MDT reserved for early investors (11%)
    uint256 public constant INVESTORS_TOKENS_RESERVED = 110 * (10**6) * (10**decimals);

    // 200 million MDT reserved for bonus giveaway (20%)
    uint256 public constant BONUS_TOKENS_RESERVED = 200 * (10**6) * (10**decimals);

    // Token sale wallet address, contains tokens for private sale, early bird and bonus giveaway
    address public tokenSaleAddress;

    // MDT team wallet address
    address public mdtTeamAddress;

    // User Growth Pool wallet address
    address public userGrowthAddress;

    // Early Investors wallet address
    address public investorsAddress;

    // MDT team foundation wallet address, contains tokens which were not sold during token sale and unraised bonus
    address public mdtFoundationAddress;

    event Burn(address indexed _burner, uint256 _value);

    /// @dev Reverts if address is 0x0 or this token address
    modifier validRecipient(address _recipient) {
        require(_recipient != address(0) && _recipient != address(this));
        _;
    }

    /**
    * @dev MDToken contract constructor.
    * @param _tokenSaleAddress address The token sale address.
    * @param _mdtTeamAddress address The MDT team address.
    * @param _userGrowthAddress address The user growth address.
    * @param _investorsAddress address The investors address.
    * @param _mdtFoundationAddress address The MDT Foundation address.
    * @param _presaleAmount uint256 Amount of MDT tokens sold during presale.
    * @param _earlybirdAmount uint256 Amount of MDT tokens to sold during early bird.
    */
    function MDToken(
        address _tokenSaleAddress,
        address _mdtTeamAddress,
        address _userGrowthAddress,
        address _investorsAddress,
        address _mdtFoundationAddress,
        uint256 _presaleAmount,
        uint256 _earlybirdAmount)
        public
    {

        require(_tokenSaleAddress != address(0));
        require(_mdtTeamAddress != address(0));
        require(_userGrowthAddress != address(0));
        require(_investorsAddress != address(0));
        require(_mdtFoundationAddress != address(0));

        tokenSaleAddress = _tokenSaleAddress;
        mdtTeamAddress = _mdtTeamAddress;
        userGrowthAddress = _userGrowthAddress;
        investorsAddress = _investorsAddress;
        mdtFoundationAddress = _mdtFoundationAddress;

        // issue tokens to token sale, MDT team, etc
        uint256 saleAmount = _presaleAmount.add(_earlybirdAmount).add(BONUS_TOKENS_RESERVED);
        mint(tokenSaleAddress, saleAmount);
        mint(mdtTeamAddress, TEAM_TOKENS_RESERVED);
        mint(userGrowthAddress, USER_GROWTH_TOKENS_RESERVED);
        mint(investorsAddress, INVESTORS_TOKENS_RESERVED);

        // issue remaining tokens to MDT Foundation
        uint256 remainingTokens = maxSupply.sub(totalSupply);
        if (remainingTokens > 0) {
            mint(mdtFoundationAddress, remainingTokens);
        }
    }

    /**
    * @dev Mint MDT tokens. (internal use only)
    * @param _to address Address to send minted MDT to.
    * @param _amount uint256 Amount of MDT tokens to mint.
    */
    function mint(address _to, uint256 _amount)
        private
        validRecipient(_to)
        returns (bool)
    {
        require(totalSupply.add(_amount) <= maxSupply);
        totalSupply = totalSupply.add(_amount);
        balances[_to] = balances[_to].add(_amount);

        Transfer(0x0, _to, _amount);
        return true;
    }

    /**
    * @dev Aprove the passed address to spend the specified amount of tokens on behalf of msg.sender.
    * @param _spender address The address which will spend the funds.
    * @param _value uint256 The amount of tokens to be spent.
    */
    function approve(address _spender, uint256 _value)
        public
        validRecipient(_spender)
        returns (bool)
    {
        return super.approve(_spender, _value);
    }

    /**
    * @dev Transfer token for a specified address.
    * @param _to address The address to transfer to.
    * @param _value uint256 The amount to be transferred.
    */
    function transfer(address _to, uint256 _value)
        public
        validRecipient(_to)
        returns (bool)
    {
        return super.transfer(_to, _value);
    }

    /**
    * @dev Transfer token to a contract address with additional data if the recipient is a contact.
    * @param _to address The address to transfer to.
    * @param _value uint256 The amount to be transferred.
    * @param _data bytes The extra data to be passed to the receiving contract.
    */
    function transferAndCall(address _to, uint256 _value, bytes _data)
        public
        validRecipient(_to)
        returns (bool success)
    {
        return super.transferAndCall(_to, _value, _data);
    }

    /**
    * @dev Transfer tokens from one address to another.
    * @param _from address The address which you want to send tokens from.
    * @param _to address The address which you want to transfer to.
    * @param _value uint256 the amout of tokens to be transfered.
    */
    function transferFrom(address _from, address _to, uint256 _value)
        public
        validRecipient(_to)
        returns (bool)
    {
        return super.transferFrom(_from, _to, _value);
    }

    /**
     * @dev Burn tokens. (token owner only)
     * @param _value uint256 The amount to be burned.
     * @return always true.
     */
    function burn(uint256 _value)
        public
        onlyOwner
        returns (bool)
    {
        balances[msg.sender] = balances[msg.sender].sub(_value);
        totalSupply = totalSupply.sub(_value);
        Burn(msg.sender, _value);
        return true;
    }

    /**
     * @dev Burn tokens on behalf of someone. (token owner only)
     * @param _from address The address of the owner of the token.
     * @param _value uint256 The amount to be burned.
     * @return always true.
     */
    function burnFrom(address _from, uint256 _value)
        public
        onlyOwner
        returns(bool)
    {
        var _allowance = allowed[_from][msg.sender];
        balances[_from] = balances[_from].sub(_value);
        allowed[_from][msg.sender] = _allowance.sub(_value);
        totalSupply = totalSupply.sub(_value);
        Burn(_from, _value);
        return true;
    }

    /**
     * @dev Transfer to owner any tokens send by mistake to this contract. (token owner only)
     * @param token ERC20 The address of the token to transfer.
     * @param amount uint256 The amount to be transfered.
     */
    function emergencyERC20Drain(ERC20 token, uint256 amount)
        public
        onlyOwner
    {
        token.transfer(owner, amount);
    }

    /**
     * @dev Change to a new token sale address. (token owner only)
     * @param _tokenSaleAddress address The new token sale address.
     */
    function changeTokenSaleAddress(address _tokenSaleAddress)
        public
        onlyOwner
        validRecipient(_tokenSaleAddress)
    {
        tokenSaleAddress = _tokenSaleAddress;
    }

    /**
     * @dev Change to a new MDT team address. (token owner only)
     * @param _mdtTeamAddress address The new MDT team address.
     */
    function changeMdtTeamAddress(address _mdtTeamAddress)
        public
        onlyOwner
        validRecipient(_mdtTeamAddress)
    {
        mdtTeamAddress = _mdtTeamAddress;
    }

    /**
     * @dev Change to a new user growth address. (token owner only)
     * @param _userGrowthAddress address The new user growth address.
     */
    function changeUserGrowthAddress(address _userGrowthAddress)
        public
        onlyOwner
        validRecipient(_userGrowthAddress)
    {
        userGrowthAddress = _userGrowthAddress;
    }

    /**
     * @dev Change to a new investors address. (token owner only)
     * @param _investorsAddress address The new investors address.
     */
    function changeInvestorsAddress(address _investorsAddress)
        public
        onlyOwner
        validRecipient(_investorsAddress)
    {
        investorsAddress = _investorsAddress;
    }

    /**
     * @dev Change to a new MDT Foundation address. (token owner only)
     * @param _mdtFoundationAddress address The new MDT Foundation address.
     */
    function changeMdtFoundationAddress(address _mdtFoundationAddress)
        public
        onlyOwner
        validRecipient(_mdtFoundationAddress)
    {
        mdtFoundationAddress = _mdtFoundationAddress;
    }
}