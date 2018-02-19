pragma solidity ^0.4.11;

contract Whitelist {
    address public owner;

    address[] public acceptedAddresses;
    mapping(address => uint) public accepted;

    modifier onlyOwner() {
        require(msg.sender == owner);

        _;
    }

    function Whitelist(address _owner, address[] _acceptedAddresses) public {
        // Since the Whitelist is created by the SyndicationFactory, msg.sender is the Factory address,
        // so we need to pass the owner address to the constructor
        owner = _owner;
        acceptedAddresses = _acceptedAddresses;
        for (uint i = 0; i < acceptedAddresses.length; i++) {
            require(acceptedAddresses[i] != address(0));
            accepted[acceptedAddresses[i]] = 1;
        }
    }

    function accept(address a) onlyOwner public {
        // check if the address has already been added
        if (accepted[a] == 1) {
            return;
        }
        acceptedAddresses.push(a);
        accepted[a] = 1;
    }

    function acceptAddresses(address[] _addresses) onlyOwner public {
        for (uint i = 0; i < _addresses.length; i++) {
            accept(_addresses[i]);
        }
    }

    function getWhitelist() public constant returns (address[]) {
        return acceptedAddresses;
    }
}