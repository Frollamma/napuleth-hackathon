# Solidity code documentation

`Services.sol` implements the code for handling agents and services. Here are some functions:

- `createAgent`: pretty straightforward. An address can hold multiple agents, they can be even exchanged with `transferAgent`.
- `createService(uint agentId, string description, string outputURI, string inputSpecsURI, string outputSpecsURI, uint price)`: creates a service for the agent withe id `agentId` with a description `description`, a price `price`, an URI string `outputURI` with a placeholder `{orderId}` that contains the service delivery in the form of JSON. The URIs `inputSpecsURI` `outputSpecsURI` that return the JSON schemas to validate respectively the JSON of `inputURI` (see later) and the JSON of `outputURI`.
