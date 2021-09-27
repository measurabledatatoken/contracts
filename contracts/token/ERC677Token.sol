pragma solidity ^0.5.10;

import './ERC677.sol';
import './ERC677Receiver.sol';

contract ERC677Token is ERC677 {

    /**
    * @dev Transfer token to a contract address with additional data if the recipient is a contact.
    * @param _to address The address to transfer to.
    * @param _value uint256 The amount to be transferred.
    * @param _data bytes The extra data to be passed to the receiving contract.
    */
    function transferAndCall(address _to, uint256 _value, bytes _data) public returns (bool success) {
        require(super.transfer(_to, _value));
        ERC677Transfer(msg.sender, _to, _value, _data);
        if (isContract(_to)) {
            contractFallback(_to, _value, _data);
        }
        return true;
    }

    // PRIVATE

    function contractFallback(address _to, uint256 _value, bytes _data) private {
        ERC677Receiver receiver = ERC677Receiver(_to);
        require(receiver.onTokenTransfer(msg.sender, _value, _data));
    }

    // assemble the given address bytecode. If bytecode exists then the _addr is a contract.
    function isContract(address _addr) private view returns (bool hasCode) {
        uint length;
        assembly { length := extcodesize(_addr) }
        return length > 0;
    }
}