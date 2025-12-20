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

## Features

1. Fixed-price purchase system with tax
2. Configurable refund policy
3. Two-step ownership transfer

```solidity
new Shop(
    1e16,       // 0.01 ETH price
    100,        // 10% tax (100/1000)
    1000,       // Tax base
    500,        // 50% refund (500/1000)
    1000,       // Refund base
    24 hours    // 24-hour refund window
);
```

## 🚀 Quick Start

```bash
# Install dependencies
forge install

# Run tests
forge test

# Check coverage
forge coverage

# Gas snapshot
forge snapshot

# Deploy
forge script script/Shop.s.sol --rpc-url $RPC_URL --broadcast
```

## 📖 Documentation

For detailed contract documentation, see [src/README.md](src/README.md)

## 🧪 Testing

```bash
forge test -vv              # Verbose output
forge test --gas-report     # Gas usage report
```

## 📜 License

MIT License - see [LICENSE](LICENSE) for details.

## 🔗 Links

- [Foundry Documentation](https://book.getfoundry.sh/)
- [Solidity Documentation](https://docs.soliditylang.org/)

**Built with ❤️**
