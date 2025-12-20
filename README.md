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

**A production-ready, trust-minimized e-commerce smart contract with buyer protections, flexible seller withdrawals, and game theory-aligned incentives.**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Solidity: 0.8.30](https://img.shields.io/badge/Solidity-0.8.30-blue.svg)](https://soliditylang.org/)
[![Tests: 74/74](https://img.shields.io/badge/Tests-74%2F74-brightgreen.svg)]()

---

## 🌟 Features

### **For Buyers** 🛍️

- ✅ **24-Hour Refund Guarantee** - Get 50% back within 24 hours, no questions asked
- ✅ **Refund Even After Confirmation** - Changed your mind? Still refundable within 24 hours
- ✅ **Mathematically Guaranteed** - Funds locked during refund period by smart contract
- ✅ **Game Theory Protection** - Popular shops = stronger guarantees for all buyers
- ✅ **Transparent Accounting** - All amounts include tax, no hidden fees
- ✅ **No Direct Transfer Exploits** - Contract rejects manipulation attempts

### **For Sellers** 💼

- ✅ **Flexible Withdrawal Strategies** - Choose between growth, cash flow, or hybrid approaches
- ✅ **Confirmation System** - Buyers can confirm receipt for faster seller access to funds
- ✅ **Partial Withdrawals** - Access to 50% of unconfirmed funds during active periods
- ✅ **Strategic Shop Closure** - Close temporarily to access full liquidity
- ✅ **Two-Step Ownership Transfer** - Safe business handover mechanism
- ✅ **Open/Close Control** - Manage shop status for maintenance or planning

### **Security** 🔒

- ✅ **Reentrancy Protection** - CEI (Checks-Effects-Interactions) pattern
- ✅ **Accounting Integrity** - Fixed critical accounting vulnerabilities
- ✅ **Refund Period Protection** - Confirmed funds locked until refund windows expire
- ✅ **Underflow Prevention** - Safe arithmetic in all operations
- ✅ **Access Control** - Strict owner-only functions with modifiers
- ✅ **Comprehensive Testing** - 74 tests covering all edge cases

---

## 📚 Documentation

### **For Buyers** 🛍️

**→ [BUYER_GUIDE.md](BUYER_GUIDE.md)**

Complete guide covering:

- How to buy and calculate costs
- Understanding your order and refund rights
- Confirming receipt of service
- Timeline and deadlines
- Why you're protected (game theory analysis)
- FAQ and technical reference

*Perfect for customers who want to understand their rights and protections.*

### **For Sellers** 💼

**→ [OWNER_GUIDE.md](OWNER_GUIDE.md)**

Complete operational manual covering:

- Shop management (open/close)
- Understanding withdrawals (full vs partial)
- 4 complete business strategies with pros/cons
- Cash flow planning and projections
- Ownership transfer procedures
- Best practices and risk management

*Perfect for shop operators who want to optimize their business.*

---

## 🚀 Quick Start

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation) installed

### Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/shop.git
cd shop

# Install dependencies
forge install

# Build contracts
forge build

# Run tests
forge test
```

### Deploy

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

**Deploy script:**

```bash
forge script script/Shop.s.sol:DeployShop --rpc-url $RPC_URL --broadcast --verify
```

---

## 🏗️ Architecture

### Core Components

```
┌─────────────────────────────────────────────────────┐
│                    Shop Contract                     │
├─────────────────────────────────────────────────────┤
│                                                      │
│  Buyer Functions:                                    │
│  • buy() - Place order                              │
│  • confirmReceived() - Confirm service              │
│  • refund() - Request refund                        │
│  • getOrder() - View order details                  │
│                                                      │
│  Owner Functions:                                    │
│  • withdraw() - Withdraw funds                      │
│  • openShop() / closeShop() - Control status       │
│  • transferOwnership() - Initiate transfer         │
│  • acceptOwnership() - Complete transfer           │
│                                                      │
│  State:                                              │
│  • orders - Order storage                           │
│  • totalConfirmedAmount - Confirmed funds tracking │
│  • lastBuy - Timestamp of last purchase            │
│  • partialWithdrawal - Withdrawal state            │
│                                                      │
└─────────────────────────────────────────────────────┘
```

### Key Mechanisms

#### **1. Dual Withdrawal Mode**

```
┌─────────────────────────────────────┐
│   lastBuy + 24 hours < now?         │
│                                     │
│   YES                     NO        │
│    ↓                       ↓        │
│ FULL MODE           PARTIAL MODE    │
│ • Withdraw all      • 50% unconfirmed only │
│ • Reset confirmed   • Once per period      │
│ • Reset flags       • Confirmed locked     │
└─────────────────────────────────────┘
```

#### **2. Refund Period Protection**

```
User buys → [24-hour window] → Window expires
    ↓              ↓                   ↓
Can refund    Can refund         Cannot refund
Funds locked  Funds locked       Owner can withdraw
```

During the 24-hour window:

- ✅ Buyer can refund anytime (gets 50% back)
- ✅ Confirmed funds are **locked** from owner withdrawal
- ✅ Owner can only access 50% of unconfirmed funds (once)

#### **3. The "Popular Shop" Effect**

Every purchase updates `lastBuy`:

```solidity
lastBuy = block.timestamp;  // Updated on each buy()
```

**Result:**

- Continuous orders = `lastBuy` keeps updating
- Owner stuck in PARTIAL mode = funds stay locked
- All buyers protected by perpetual refund coverage

**This creates game theory protection:**

- Popular shop = maximum buyer safety
- Owner must choose: Growth or Liquidity
- Economics align with good behavior

---

## 🧪 Testing

### Test Coverage

```bash
# Run all tests
forge test

# Verbose output
forge test -vvv

# Gas report
forge test --gas-report

# Coverage report
forge coverage
```

### Known Security Features

1. **Checks-Effects-Interactions Pattern**

   ```solidity
   // Example from refund()
   // 1. Checks
   if (order.buyer != msg.sender) revert;

   // 2. Effects
   refunds[orderId] = true;
   totalConfirmedAmount -= order.amount;

   // 3. Interactions
   (bool success,) = payable(msg.sender).call{value: amount}("");
   ```

2. **Arithmetic Safety**
   - Solidity 0.8.30 built-in overflow/underflow protection
   - All math operations validated in tests

3. **Direct Transfer Prevention**

   ```solidity
   receive() external payable {
       revert("Direct transfers not allowed");
   }
   ```

4. **Refund Period Protection**

   ```solidity
   // Confirmed funds locked during refund period
   if (lastBuy + REFUND_POLICY < block.timestamp) {
       // Only then can owner access confirmed funds
   }
   ```

### Security Considerations

⚠️ **Owner Private Key:** If compromised, attacker can withdraw funds and transfer ownership. Use hardware wallet.

⚠️ **Immutable Parameters:** Cannot change price, tax, or refund policy after deployment. Plan carefully.

⚠️ **Smart Contract Risk:** While thoroughly tested, use at your own risk. Start with small amounts.

## 📊 Example Usage

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

## 🎯 Business Strategies

### Strategy Comparison

| Strategy | Uptime | Liquidity | Revenue | Best For |
|----------|--------|-----------|---------|----------|
| **Patient Accumulator** | 100% | Low, then high | Maximum | Long-term growth |
| **Weekly Closer** | ~85% | High, regular | High | Regular cash flow |
| **Opportunist** | Variable | Variable | High | Active management |
| **Bootstrapper** | 100% | Very low | Maximum | Reinvestment focus |

See [OWNER_GUIDE.md](OWNER_GUIDE.md) for detailed strategy breakdowns with pros/cons and implementation guides.

## 🔧 Technical Reference

### Contract Functions

#### Public/External Functions

| Function | Access | Description |
|----------|--------|-------------|
| `buy()` | Anyone | Place an order (payable) |
| `refund(bytes32)` | Order buyer | Request refund within 24h |
| `confirmReceived(bytes32)` | Order buyer | Confirm receipt of service |
| `getOrder(bytes32)` | Anyone | View order details |
| `withdraw()` | Owner | Withdraw available funds |
| `openShop()` | Owner | Open shop for orders |
| `closeShop()` | Owner | Close shop |
| `transferOwnership(address)` | Owner | Initiate ownership transfer |
| `acceptOwnership()` | Pending owner | Accept ownership |
| `cancelOwnershipTransfer()` | Owner | Cancel pending transfer |

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

### Format

```bash
forge fmt
```

### Coverage

```bash
forge coverage
```

### Deploy Locally

```bash
# Start local node
anvil

# Deploy (in another terminal)
forge script script/Shop.s.sol:DeployShop --rpc-url http://localhost:8545 --broadcast
```

## 📝 Changelog

### Version 1.0.0 (Current)

**✅ Features Added:**

- Confirmation system for buyers
- `totalConfirmedAmount` tracking
- Dual withdrawal modes (full/partial)
- Refund period protection for confirmed funds
- Direct ETH transfer blocking

**🔧 Security Fixes:**

- Fixed TAX not included in order amounts
- Fixed refund calculation to include TAX
- Fixed withdrawal accounting for confirmed amounts
- Fixed `totalConfirmedAmount` reset logic
- Fixed underflow risks in refund after withdrawal

**📚 Documentation:**

- Complete Buyer's Guide
- Complete Owner's Guide
- Updated README with current features
- Comprehensive tests with descriptions

## 🤝 Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Add tests for new features
4. Ensure all tests pass
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🔗 Resources

### Documentation

- [Buyer's Guide](BUYER_GUIDE.md) - Complete guide for customers
- [Owner's Guide](OWNER_GUIDE.md) - Complete guide for shop operators

### Development

- [Foundry Book](https://book.getfoundry.sh/) - Foundry documentation
- [Solidity Docs](https://docs.soliditylang.org/) - Solidity language reference

## 💬 Support

- **Issues:** [GitHub Issues](https://github.com/yourusername/shop/issues)
- **Discussions:** [GitHub Discussions](https://github.com/yourusername/shop/discussions)

**Built with ❤️ using Foundry**

*Last Updated: 2025-12-20*
*Version: 1.0.0*
