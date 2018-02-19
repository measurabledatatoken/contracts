pragma solidity ^0.4.17;

import './MDTokenOld.sol';
import './math/SafeMath.sol';
import './ownership/Ownable.sol';
import './Whitelist.sol';

contract MDTokenCrowdsale is Ownable {
    using SafeMath for uint256;

    // enum State { Active, Finished }

    // MDT token contract
    MDTokenOld public token;

    // Received funds are forwarded to this address.
    address public fundingRecipient;

    // minimum investment in wei
    uint256 public MIN_INVESTMENT_IN_WEI = 0.1 ether;

    // MDT token decimal
    uint256 public constant TOKEN_UNIT = 10 ** 18;

    // max token supply
    uint256 public constant MAX_TOKENS_SUPPLY = 10 * (10**8) * TOKEN_UNIT; // 1 billion MDT

    // tokens reserved for teams, investors and user growth pool
    uint256 public constant TEAM_TOKENS_RESERVED = 240 * (10**6) * TOKEN_UNIT; // 240 million MDT reserved for MDT team (24%)
    uint256 public constant INVESTORS_TOKENS_RESERVED = 110 * (10**6) * TOKEN_UNIT; // 110 million MDT reserved for early investors (11%)
    uint256 public constant USER_GROWTH_TOKENS_RESERVED = 150 * (10**6) * TOKEN_UNIT; // 150 million MDT reserved for user growth (15%)

    // 200 million MDT for sale during ICO
    uint256 public constant MAX_TOKENS_FOR_REGULAR_SALE = 200 * (10**6) * TOKEN_UNIT;
    uint256 public HARD_CAP_IN_WEI = MAX_TOKENS_FOR_REGULAR_SALE / REGULAR_MDT_PER_WEI;

    // MDT to 1 ether ratio during pre-sale
    uint256 public constant PRESALE_MDT_PER_ETHER = 7500 * TOKEN_UNIT;

    // MDT to 1 ether ratio during early bird
    uint256 public constant EARLY_BIRD_MDT_PER_ETHER = 6250 * TOKEN_UNIT;

    // MDT to 1 ether ratio during regular ICO
    uint256 public constant REGULAR_MDT_PER_ETHER = 5000 * TOKEN_UNIT;

    // MDT to 1 wei ratio during pre-sale
    uint256 public constant PRESALE_MDT_PER_WEI = PRESALE_MDT_PER_ETHER / uint256(1 ether);

    // MDT to 1 wei ratio during early bird
    uint256 public constant EARLY_BIRD_MDT_PER_WEI = EARLY_BIRD_MDT_PER_ETHER / uint256(1 ether);

    // MDT to 1 wei ratio during regular ICO
    uint256 public constant REGULAR_MDT_PER_WEI = REGULAR_MDT_PER_ETHER / uint256(1 ether);

    // Crowdsale start and end timestamps
    uint256 public startTime;
    uint256 public endTime;

    address public privateSaleAddress;
    address public earlyBirdAddress;
    address public mdtTeamAddress;
    address public userGrowthAddress;
    address public investorsAddress;
    address public mdtFoundationAddress;

    // Amount of tokens sold during pre sale
    uint256 public tokensSoldDuringPreSale;

    // Amount of tokens sold during early bird
    uint256 public tokensSoldDuringEarlyBird;

    // Amount of tokens sold until now in the sale.
    uint256 public totalTokensSold = 0;

    // amount of raised money in wei
    uint256 public weiRaised = 0;

    // participation cap for each user. If it’s 0, it’s uncapped (unlimited)
    uint256 public participationCap;

    // defines the maximum number of wei for the crowdsale. If it’s 0, it’s uncapped (unlimited)
    uint256 public maxAllocation;

    // Whitelist contract contains addresses allowed for contribution
    Whitelist public whitelist;

    // how many token units a buyer gets per wei
    uint256 public exchangeRate;

    // accumulated ammount each buyer has purchased so far
    mapping (address => uint256) public participantsPurchaseHistory;

    // list of buyers
    address[] public participants;

    event TokensPurchased(address indexed _purchaser, address indexed _beneficiary, uint256 _weiAmount, uint256 _tokens);

    modifier onlyDuringSale() {
        require(!hasEnded() && now >= startTime);

        _;
    }

    modifier onlyAfterSale() {
        require(hasEnded());

        _;
    }

    function MDTokenCrowdsale(address _fundingAddress, address _whitelist,
        address _privateSaleAddress, address _earlyBirdAddress, address _mdtTeamAddress,
        address _userGrowthAddress, address _investorsAddress, address _mdtFoundationAddress,
        uint256 _presaleAmount, uint256 _earlybirdAmount, uint256 _maxAllocation, uint256 _participationCap,
        uint256 _startTime, uint256 _endTime) 
        public
    {

        require(_fundingAddress != address(0));
        require(_whitelist != address(0));
        require(_privateSaleAddress != address(0));
        require(_earlyBirdAddress != address(0));
        require(_mdtTeamAddress != address(0));
        require(_userGrowthAddress != address(0));
        require(_investorsAddress != address(0));
        require(_mdtFoundationAddress != address(0));
        require(_startTime > now);
        require(_endTime >= _startTime);

        // Deploy a new MDToken contract
        token = new MDTokenOld();

        // Get reference to the whitelist contract
        whitelist = Whitelist(_whitelist);

        fundingRecipient = _fundingAddress;
        privateSaleAddress = _privateSaleAddress;
        earlyBirdAddress = _earlyBirdAddress;
        mdtTeamAddress = _mdtTeamAddress;
        userGrowthAddress = _userGrowthAddress;
        investorsAddress = _investorsAddress;
        mdtFoundationAddress = _mdtFoundationAddress;

        tokensSoldDuringPreSale = _presaleAmount;
        tokensSoldDuringEarlyBird = _earlybirdAmount;
        maxAllocation = _maxAllocation;
        participationCap = _participationCap;
        startTime = _startTime;
        endTime = _endTime;
        exchangeRate = REGULAR_MDT_PER_WEI;

        // issue tokens to private sale, early bird, MDT team, etc
        issueTokens(privateSaleAddress, tokensSoldDuringPreSale);
        issueTokens(earlyBirdAddress, tokensSoldDuringEarlyBird);
        issueTokens(mdtTeamAddress, TEAM_TOKENS_RESERVED);
        issueTokens(userGrowthAddress, USER_GROWTH_TOKENS_RESERVED);
        issueTokens(investorsAddress, INVESTORS_TOKENS_RESERVED);
    }

    function () external payable onlyDuringSale {
        purchaseTokens(msg.sender);
    }

    function purchaseTokens(address _recipient) public payable onlyDuringSale {
        require(_recipient != address(0));
        require(whitelist.accepted(msg.sender) == 1);

        require(msg.value >= MIN_INVESTMENT_IN_WEI);

        // ensure the partipation cap
        uint256 weiParticipated = participantsPurchaseHistory[msg.sender];
        uint256 maxWeiAllowedToParticipate;
        uint256 weiToParticipate;
        if (participationCap > 0) {
            maxWeiAllowedToParticipate = SafeMath.min256(participationCap.sub(weiParticipated), msg.value);
            require(maxWeiAllowedToParticipate > 0);
        } else {
            maxWeiAllowedToParticipate = msg.value;
        }

        // ensure the max allocation cap
        if (maxAllocation > 0) {
            uint256 weiLeftForSale = maxAllocation.sub(weiParticipated);
            weiToParticipate = SafeMath.min256(maxWeiAllowedToParticipate, weiLeftForSale);
        } else { // no sales limit
            weiToParticipate = maxWeiAllowedToParticipate;
        }
        require(weiToParticipate > 0);

        // update state
        weiRaised = weiRaised.add(weiToParticipate);

        if (participantsPurchaseHistory[msg.sender] == 0) {
            participantsPurchaseHistory[msg.sender] = weiToParticipate;
            participants.push(msg.sender);
        } else {
            participantsPurchaseHistory[msg.sender] = weiParticipated.add(weiToParticipate);
        }

        // transfer funds to the funding address
        fundingRecipient.transfer(weiToParticipate);

        // issue tokens
        uint256 tokenAmount = weiToParticipate.mul(REGULAR_MDT_PER_WEI);
        issueTokens(_recipient, tokenAmount);
        totalTokensSold = totalTokensSold.add(tokenAmount);

        // Partial refund if full participation not possible
        // e.g. due to cap being reached.
        uint256 refund = msg.value.sub(weiToParticipate);
        if (refund > 0) {
            msg.sender.transfer(refund);
        }

        TokensPurchased(msg.sender, _recipient, weiToParticipate, tokenAmount);
    }

    function issueTokens(address _recipient, uint256 _tokens) private {
        token.mint(_recipient, _tokens);
    }

    function getPartipants() public constant returns (address[]) {
        return participants;
    }

    function getContribution(address addr) public constant returns (uint256) {
        return participantsPurchaseHistory[addr];
    }

    function getPurchasedTokenAmount(address addr) public constant returns (uint256) {
        return participantsPurchaseHistory[addr].mul(REGULAR_MDT_PER_WEI);
    }

    function getTotalPurchasedTokens() public constant returns (uint256) {
        // return weiRaised.mul(REGULAR_MDT_PER_WEI);
        return totalTokensSold;
    }

    // @return true if syndication has ended
    function hasEnded() public constant returns (bool) {
        bool capReached;
        if (maxAllocation > 0) {
            capReached = weiRaised >= maxAllocation;
        } else {
            capReached = false;
        }
        bool hasExpired = now > endTime;
        return hasExpired || capReached;
    }

    /**
     * @dev Transfer the unsold tokens to the MDT Foundation wallet
     * @dev Only for owner
     */
    function drainRemainingToken() public onlyAfterSale onlyOwner {
        uint256 remainingTokens = token.maxSupply().sub(token.totalSupply());
        if (remainingTokens > 0) {
            token.mint(mdtFoundationAddress, remainingTokens);
        }
    }

    function finalize() external onlyAfterSale onlyOwner {
        if (!token.isMinting()) {
            revert();
        }

        // issue remaining tokens to MDT foundation
        drainRemainingToken();

        // ensure all tokens have been minted after crowdsale
        require(token.totalSupply() == token.maxSupply());

        // finish minting
        token.endMinting();
    }
}