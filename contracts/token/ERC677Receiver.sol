pragma solidity ^0.4.11;

contract ERC677Receiver {
    function onTokenTransfer(address _sender, uint _value, bytes _data) public returns (bool success);
}