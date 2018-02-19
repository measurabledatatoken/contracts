pragma solidity ^0.4.11;

import "./ERC20.sol";

contract ERC677 is ERC20 {
    function transferAndCall(address _to, uint256 _value, bytes _data) public returns (bool success);
    
    event ERC677Transfer(address indexed _from, address indexed _to, uint256 _value, bytes _data);
}