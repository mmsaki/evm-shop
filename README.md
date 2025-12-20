# 🛒 EVM Shop

```
                                                 █████
                                                ░░███
  ██████  █████ █████ █████████████       █████  ░███████    ██████  ████████
 ███░░███░░███ ░░███ ░░███░░███░░███     ███░░   ░███░░███  ███░░███░░███░░███
░███████  ░███  ░███  ░███ ░███ ░███    ░░█████  ░███ ░███ ░███ ░███ ░███ ░███
░███░░░   ░░███ ███   ░███ ░███ ░███     ░░░░███ ░███ ░███ ░███ ░███ ░███ ░███
░░██████   ░░█████    █████░███ █████    ██████  ████ █████░░██████  ░███████
 ░░░░░░     ░░░░░    ░░░░░ ░░░ ░░░░░    ░░░░░░  ░░░░ ░░░░░  ░░░░░░   ░███░░░
                                                                     ░███
                                                                     █████
                                                                    ░░░░░


```

**A trust-minimized e-commerce smart contract with buyer protections, flexible seller withdrawals.**

![GitHub License](https://img.shields.io/github/license/mmsaki/evm-shop)

[![Solidity: 0.8.30](https://img.shields.io/badge/Solidity-0.8.30-blue.svg)](https://soliditylang.org/)
[![Tests](https://github.com/mmsaki/evm-shop/actions/workflows/test.yml/badge.svg)](https://github.com/mmsaki/evm-shop/actions/workflows/test.yml)

## 🔗 Resources

- [Buyer's Guide](BUYER_GUIDE.md) - Complete guide for customers
- [Owner's Guide](OWNER_GUIDE.md) - Complete guide for shop operators

## 🛠️ Development

### Build

```bash
forge build
```

### Test

```bash
# All tests
forge test

# Specific test
forge test --match-test test_accounting_confirmed_amount_includes_tax

# With gas report
forge test --gas-report
```

### 🚀 Deploy config

```solidity
// Example deployment parameters
new Shop(
    1e16,       // PRICE: 0.01 ETH per item
    100,        // TAX: 10% (100 basis points out of 1000)
    1000,       // TAX_BASE: Denominator for tax calculation
    500,        // REFUND_RATE: 50% refund (500 out of 1000)
    1000,       // REFUND_BASE: Denominator for refund calculation
    24 hours    // REFUND_POLICY: 24-hour refund window
);
```

### As a Buyer

```solidity
// 1. Calculate total cost
uint256 price = shop.PRICE();        // 0.01 ETH
uint256 total = price + (price * shop.TAX() / shop.TAX_BASE());  // 0.011 ETH

// 2. Buy
shop.buy{value: total}();

// 3. Calculate your order ID
uint256 nonce = shop.nonces(msg.sender) - 1;
bytes32 orderId = keccak256(abi.encode(msg.sender, nonce));

// 4. (Optional) Confirm receipt
shop.confirmReceived(orderId);

// 5. (If needed) Refund within 24 hours
shop.refund(orderId);  // Get 50% back
```

### As an Owner

```solidity
// Open shop
shop.openShop();

// Check balance and confirmed amounts
uint256 balance = address(shop).balance;
uint256 confirmed = shop.totalConfirmedAmount();

// Withdraw (automatically handles full/partial mode)
shop.withdraw();

// Close shop for maintenance
shop.closeShop();

// Transfer ownership (2-step)
shop.transferOwnership(payable(newOwner));
// (newOwner calls:)
shop.acceptOwnership();
```

### Events

```solidity
event BuyOrder(bytes32 indexed orderId, uint256 amount);
event RefundProcessed(bytes32 indexed orderId, uint256 amount);
event OrderConfirmed(bytes32 indexed orderId);
event ShopOpen(uint256 timestamp);
event ShopClosed(uint256 timestamp);
event OwnershipTransferInitiated(address indexed previousOwner, address indexed newOwner);
event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
```

### Custom Errors

```solidity
error ExcessAmount();
error InsuffientAmount();
error DuplicateRefundClaim();
error RefundPolicyExpired();
error InvalidRefundBenefiary();
error ShopIsClosed();
error UnauthorizedAccess();
error MissingTax();
error WaitUntilRefundPeriodPassed();
error InvalidConstructorParameters();
error InvalidPendingOwner();
error NoPendingOwnershipTransfer();
error TransferFailed();
error OrderAlreadyConfirmed();
error InvalidOrder();
```

### Development

- [Foundry Book](https://book.getfoundry.sh/) - Foundry documentation
- [Solidity Docs](https://docs.soliditylang.org/) - Solidity language reference

## 💬 Support

- **Issues:** [GitHub Issues](https://github.com/yourusername/shop/issues)
- **Discussions:** [GitHub Discussions](https://github.com/yourusername/shop/discussions)

**Built with ❤️ using Foundry**

*Last Updated: 2025-12-20*
*Version: 1.0.0*
