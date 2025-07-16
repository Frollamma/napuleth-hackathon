pragma solidity ^0.8.20;

contract ServiceRegistry {
    struct Seller {
        uint id;
        string name;
        string bio;
        string imageURI;
        string contact;
        address owner;
    }

    struct Service {
        string description;
        string outputURI;
        string inputSpecsURI;
        string outputSpecsURI;
        uint price;
        uint completedServices;
        uint failedServices;
        uint totReviews;
        uint reputation; // sum of all review scores (for this service)
        uint sellerId;
    }

    uint public sellerCounter;
    uint public serviceCounter;

    mapping(address => uint) public ownerSellerCounter; // counts the number of sellers an address has
    mapping(uint => Seller) public idToSeller;       // sellerId to sellers
    mapping(uint => Service) public idToService;     // serviceId to services
    mapping(uint => Service[]) public sellerToServices;     // sellerId to services

    event SellerCreated(uint indexed sellerId, address indexed owner);
    event ServiceCreated(uint indexed serviceId, uint indexed sellerId);
    event SellerTransferred(uint indexed sellerId, address indexed previousOwner, address indexed newOwner);
    event SellerDeleted(uint indexed sellerId, address indexed owner);
    event ServiceDeleted(uint indexed serviceId, uint indexed sellerId, address indexed owner);

    modifier onlySellerOwner(uint sellerId) {
        require(
            idToSeller[sellerId].owner == msg.sender,
            "Not the owner of the seller"
        );
        _;
    }
    
    modifier onlyServiceOwner(uint serviceId) {
        require(
            idToSeller[idToService[serviceId].sellerId].owner == msg.sender,
            "Not the owner of the service"
        );
        _;
    }

    function createSeller(
        string calldata name,
        string calldata bio,
        string calldata imageURI,
        string calldata contact
    ) external {
      // It's ok for an address to own multiple sellers
        sellerId = sellerCounter;
        sellerCounter++;

        idToSeller[sellerId] = Seller({
            id: sellerId,
            name: name,
            bio: bio,
            imageURI: imageURI,
            contact: contact,
            owner: msg.sender
        });
        ownerSellerCounter[msg.sender]++;

        emit SellerCreated(sellerId, msg.sender);
    }

    function getSellersByOwner(address owner) external view returns(uint[] memory) {
      uint[] memory result = new uint[](ownerSellerCounter[owner]);

      uint counter = 0;
      for (uint i = 0; i < sellerCounter; i++) {
        if (idToSeller[i].owner == owner) {
          result[counter] = i;
          counter++;
        }
      }

      return result;
    }

    function createService(
        uint sellerId,
        string calldata description,
        string calldata outputURI,
        string calldata inputSpecsURI,
        string calldata outputSpecsURI,
        uint price
    ) external onlySellerOwner(sellerId) {
        serviceId = serviceCounter;
        serviceCounter++;

        idToService[serviceId] = Service({
            description: description,
            outputURI: outputURI,
            inputSpecsURI: inputSpecsURI,
            outputSpecsURI: outputSpecsURI,
            price: price,
            completedServices: 0,
            failedServices: 0,
            totReviews: 0,
            reputation: 0,
            sellerId: sellerId
        });

        emit ServiceCreated(serviceId, sellerId);
    }

    function transferSeller(address newOwner, uint sellerId) external onlySellerOwner(sellerId) {
      address previousOwner = idToSeller[sellerId].owner;

      ownerSellerCounter[msg.sender]--;
      idToSeller[sellerId].owner = newOwner;
      ownerSellerCounter[newOwner]++;

      emit SellerTransferred(sellerId, previousOwner, newOwner);
    }

    function deleteSeller(uint sellerId) external onlySellerOwner(sellerId) {
      require(sellerToServices[sellerId].length == 0, "This seller has still some services, delete them");
      address owner = idToSeller[sellerId].owner;

      delete idToSeller[sellerId];
      ownerSellerCounter[msg.sender]--;

      emit SellerDeleted(sellerId, owner);
    }

    function deleteService(uint serviceId) external onlyServiceOwner(serviceId) {
        uint sellerId = idToService[serviceId].sellerId;
        address owner = idToSeller[sellerId].owner;

        delete idToService[serviceId];

        emit ServiceDeleted(serviceId, sellerId, owner);
    }
}
