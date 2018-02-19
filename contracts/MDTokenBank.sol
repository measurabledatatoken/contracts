pragma solidity ^0.4.17;

import './math/SafeMath.sol';
import './token/ERC677Receiver.sol';
import './token/ERC20.sol';
import './ownership/Ownable.sol';

contract MDTokenBank is ERC677Receiver, Ownable {
    using SafeMath for uint256;

    mapping(address => uint256) public balances;

    address public tokenAddress;
    uint256 public totalTokensReceived;
    uint8 public secretAscii;

    event Deposit(address indexed _sender, uint256 _value);

    function MDTokenBank(address _tokenAddress, uint8 _secretAscii) public {
        tokenAddress = _tokenAddress;
        secretAscii = _secretAscii;
    }

    function setSecretAscii(uint8 _secretAscii) public onlyOwner {
        secretAscii = _secretAscii;
    }

    function onTokenTransfer(address _sender, uint _value, bytes _data) public returns (bool success) {
        // only accept callback from assigned token contract
        if (msg.sender != tokenAddress) {
            return false;
        }

        require(_data.length > 0);
        if (uint8(_data[0]) == secretAscii) { // if the first byte is character 'a', then add funds
            balances[_sender] = balances[_sender].add(_value);
            totalTokensReceived = totalTokensReceived.add(_value);
            Deposit(_sender, _value);
            return true;
        } else {
            return false;
        }
    }

    function withdraw(uint256 _amount) public returns (bool success) {
        balances[msg.sender] = balances[msg.sender].sub(_amount);
        totalTokensReceived = totalTokensReceived.sub(_amount);
        require(ERC20(tokenAddress).transfer(msg.sender, _amount) == true);
        return true;
    }
}
