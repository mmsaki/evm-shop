# Smart Contract Shop

A Solidity-based shop contract that supports purchases with tax and refund functionality.

## Features

- **Purchase System**: Buy items at a fixed price with additional tax
- **Refund Policy**: Customers can request refunds within a configurable time period after purchase
- **Shop Management**: Owner can open or close the shop
- **Fund Withdrawal**: Owner can withdraw funds with restrictions during refund periods
- **Partial Withdrawals**: Allows partial fund withdrawals before refund policy expires

## Key Functions

- `buy()`: Purchase an item by sending the required amount (price + tax)
- `refund(orderId)`: Request a refund for a specific order within the refund period
- `withdraw()`: Owner can withdraw accumulated funds
- `openShop()` / `closeShop()`: Owner controls shop availability

## Configuration

The contract is initialized with:

- `price`: Base price of items
- `tax`: Additional tax amount
- `refundRate`: Refund percentage (numerator)
- `refundBase`: Refund percentage (denominator)
- `refundPolicy`: Time window in seconds for refunds

## Installation

1. Clone the repository:

   ```bash
   git clone https://github.com/mmsaki/evm-shop.git
   cd shop
   ```

2. Install dependencies:

   ```bash
   forge install
   ```

## Testing

Run the test suite:

```bash
forge test
```

Run tests with verbose output:

```bash
forge test -v
```

## Deployment

Deploy the contract using the provided script:

```bash
forge script script/Shop.s.sol --rpc-url <your-rpc-url> --private-key <your-private-key> --broadcast
```

The script deploys the Shop contract with the following default parameters:

- Price: 0.01 ETH (1e16 wei)
- Tax: 10% (100 basis points)
- Tax Base: 1000
- Refund Rate: 50% (500/1000)
- Refund Base: 1000
- Refund Policy: 24 hours

## Events

- `BuyOrder(bytes32 orderId, uint256 amount)`: Emitted when a purchase is made
- `RefundProcessed(bytes32 orderId, uint256 amount)`: Emitted when a refund is processed
- `ShopOpen(uint256 timestamp)`: Emitted when the shop is opened
- `ShopClosed(uint256 timestamp)`: Emitted when the shop is closed

## Errors

- `ShopIsClosed()`: Thrown when attempting to buy from a closed shop
- `UnauthorizedAccess()`: Thrown when non-owner tries to access owner-only functions
- `MissingTax()`: Thrown when buying without paying the required tax
- `WaitUntilRefundPeriodPassed()`: Thrown when attempting multiple partial withdrawals within refund period

## License

This project is licensed under the MIT License.
