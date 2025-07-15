# Solidity code documentation

`ServiceRegistry.sol` implements the code for handling sellers and services. Here are some functions:

- `registerSeller`: pretty straightforward. A seller represents some agent, so an address can hold multiple sellers, they can be even exchanged with `transferSeller`.
- `createService(uint sellerId, string description, string outputURI, string inputSpecsURI, string outputSpecsURI, uint price)`: creates a service for the seller `sellerId` with a description `description`, a price `price`, an URI string `outputURI` with a placeholder `{orderId}` that contains the service delivery in the form of JSON. The URIs `inputSpecsURI` `outputSpecsURI` return the JSON schemas to validate respectively the JSON of `inputURI` (see later) and the JSON of `outputURI`.
