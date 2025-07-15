# Solidity code documentation

- `createService(string description, string dropURI, string specsURI, uint price, string contact)`: creates a service with a description `description`, a price `price`, an URI string `dropURI` with a placeholder `{orderId}` that returns a JSON and an URI `specsURI` specifying to specify the JSON schema to validate the JSON of `dropURI`. An optional `contact` string is given for off-chain communication.
