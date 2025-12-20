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

A production-ready Solidity smart contract for an e-commerce shop with built-in refund policies, two-step ownership transfer, and comprehensive security features.

## ✨ Features

- 🛒 Fixed-price purchase system with tax
- 💸 Configurable refund policy
- 🔒 Two-step ownership transfer
- 🛡️ Reentrancy protection
- ✅ Comprehensive input validation
- 🔐 Gas-efficient custom errors

## 🚀 Quick Start

```bash
# Install dependencies
forge install

# Run tests
forge test

# Deploy
forge script script/Shop.s.sol --rpc-url $RPC_URL --broadcast
```

## 📖 Documentation

For detailed contract documentation, see [src/README.md](src/README.md)

## 🧪 Testing

**54 tests** with 100% pass rate:

```bash
forge test -vv              # Verbose output
forge test --gas-report     # Gas usage report
```

## 🔧 Contract Configuration

Default deployment parameters:
- **Price**: 0.01 ETH
- **Tax**: 10%
- **Refund**: 50% within 24 hours
- **Solidity**: 0.8.30

## 📜 License

MIT License - see [LICENSE](LICENSE) for details.

## 🔗 Links

- [Foundry Documentation](https://book.getfoundry.sh/)
- [Solidity Documentation](https://docs.soliditylang.org/)

---

**Built with ❤️ using Foundry and Solidity 0.8.30**
