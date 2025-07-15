// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract ServiceRegistry {
    uint public serviceCounter;

    struct Seller {
        string name;
        string contact;
        uint completedServices;
        uint failedServices;
        uint totReviews;
        uint reputation; // sum of all review scores
    }

    struct Service {
        string description;
        string dropURI;
        string specsURI;
        uint price;
        address owner;
    }

    mapping(address => Seller) public sellers;
    mapping(uint => Service) public services;
    uint public serviceCounter;

    modifier onlyServiceOwner(uint serviceId) {
        require(services[serviceId].owner == msg.sender, "Not the owner");
        _;
    }

    function registerSeller(string calldata name, string calldata contact) external {
        require(bytes(sellers[msg.sender].name).length == 0, "Already registered");
        sellers[msg.sender] = Seller({
            name: name,
            contact: contact,
            completedServices: 0,
            failedServices: 0,
            totReviews: 0,
            reputation: 0
        });
    }

    function createService(
        string calldata description,
        string calldata dropURI,
        string calldata specsURI,
        uint price
    ) external returns (uint serviceId) {
        require(bytes(sellers[msg.sender].name).length > 0, "Seller not registered");

        serviceId = ++serviceCounter;
        services[serviceId] = Service({
            description: description,
            dropURI: dropURI,
            specsURI: specsURI,
            price: price,
            owner: msg.sender
        });

        return serviceId;
    }

    function deleteService(uint serviceId) external onlyServiceOwner(serviceId) {
        delete services[serviceId];
    }
}
