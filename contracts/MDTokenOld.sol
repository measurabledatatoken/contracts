pragma solidity ^0.4.15;

import './math/SafeMath.sol';
import './token/StandardToken.sol';
import './ownership/Ownable.sol';

/**
 * @title The MDToken contract
 * @dev The MDT Token contract
 * @author MDT Team
 */
contract MDTokenOld is StandardToken, Ownable {
    using SafeMath for uint256;

    /*
     * Token metadata
     */
    string public constant name = "Measurable Data Token";
    string public constant symbol = "MDT";
    uint256 public constant decimals = 18;
    uint256 public constant maxSupply = 10 * (10**8) * (10**decimals); // 1 billion MDT

    // Used during token sale.
    bool public isMinting = true;

    event MintingEnded();

    modifier onlyDuringMinting() {
        require(isMinting);

        _;
    }

    modifier onlyAfterMinting() {
        require(!isMinting);

        _;
    }

    /// @dev Mint MDT tokens.
    /// @param _to address Address to send minted MDT to.
    /// @param _amount uint256 Amount of MDT tokens to mint.
    function mint(address _to, uint _amount) external onlyOwner onlyDuringMinting returns (bool) {
        require(totalSupply.add(_amount) <= maxSupply);
        totalSupply = totalSupply.add(_amount);
        balances[_to] = balances[_to].add(_amount);

        Transfer(0x0, _to, _amount);
        return true;
    }

    function endMinting() external onlyOwner {
        if (!isMinting) {
            return;
        }

        isMinting = false;

        MintingEnded();
    }

    function approve(address _spender, uint256 _value) public onlyAfterMinting returns (bool) {
        return super.approve(_spender, _value);
    }

    function transfer(address _to, uint256 _value) public onlyAfterMinting returns (bool) {
        return super.transfer(_to, _value);
    }

    function transferFrom(address _from, address _to, uint256 _value) public onlyAfterMinting returns (bool) {
        return super.transferFrom(_from, _to, _value);
    }
}