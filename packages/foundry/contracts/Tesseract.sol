pragma solidity ^0.8.20;

import "./Orders.sol";

contract Tesseract is Orders {
    constructor(address initialOwner) Orders(initialOwner) {}
}
