export default [
  {
    "inputs": [
      {
        "internalType": "address",
        "name": "_proxy",
        "type": "address"
      },
      {
        "internalType": "uint256",
        "name": "_type",
        "type": "uint256"
      }
    ],
    "name": "getFeeInfo",
    "outputs": [
      {
        "internalType": "address",
        "name": "recipient",
        "type": "address"
      },
      {
        "internalType": "uint256",
        "name": "bps",
        "type": "uint256"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  }
];
