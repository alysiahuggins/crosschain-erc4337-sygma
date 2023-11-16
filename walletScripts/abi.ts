export const ERC20_ABI = [
    // Read-Only Functions
    "function balanceOf(address owner) view returns (uint256)",
    "function decimals() view returns (uint8)",
    "function symbol() view returns (string)",
  
    // Authenticated Functions
    "function transfer(address to, uint amount) returns (bool)",
    "function approve(address spender, uint amount) returns (bool)",
    "function mint(address to, uint amount)",
  
    // Events
    "event Transfer(address indexed from, address indexed to, uint amount)",
  ];


export const BRIDGE_ABI = [
  "function deposit(uint8 destinationDomainID, bytes32 resourceID, bytes calldata depositData, bytes calldata feeData) returns (uint64 depositNonce, bytes memory handlerResponse)"
];