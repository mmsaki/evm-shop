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

## Development

This project uses Foundry for testing and deployment. See the Foundry documentation for usage instructions.
