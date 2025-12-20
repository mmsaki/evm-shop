# 👔 Shop Contract - Owner's Guide

**Welcome, Shop Owner!** This guide explains how to manage your on-chain shop, plan withdrawals, and optimize your business strategy.

---

## 📋 Table of Contents

1. [Quick Start](#quick-start)
2. [Shop Management](#shop-management)
3. [Understanding Withdrawals](#understanding-withdrawals)
4. [Withdrawal Strategies](#withdrawal-strategies)
5. [Business Planning](#business-planning)
6. [Ownership Transfer](#ownership-transfer)
7. [Best Practices](#best-practices)
8. [Risk Management](#risk-management)
9. [Technical Reference](#technical-reference)
10. [Frequently Asked Questions](#frequently-asked-questions)

---

## 🚀 Quick Start

### Your Shop Parameters (Immutable)
Once deployed, these CANNOT be changed:
- **PRICE:** Base price per item
- **TAX:** Tax percentage (in basis points)
- **REFUND_RATE:** 50% (basis points: 500/1000)
- **REFUND_POLICY:** 24 hours (86400 seconds)

### Your Capabilities
- ✅ Open/close the shop
- ✅ Withdraw funds (with time-based restrictions)
- ✅ Transfer ownership (2-step process)
- ❌ Cannot change prices after deployment
- ❌ Cannot prevent refunds
- ❌ Cannot force withdrawals during refund period

### The Core Trade-Off
**You choose between two modes:**
1. **Growth Mode:** Keep shop open → More sales, locked liquidity
2. **Liquidity Mode:** Close shop → Access funds, no new sales

---

## 🏪 Shop Management

### Opening the Shop

```solidity
shop.openShop();
```

**When to open:**
- After deployment (shop starts closed)
- After a withdrawal cycle
- When ready to accept new orders

**What happens:**
- Shop status changes to open
- Buyers can place orders
- `lastBuy` timer starts/continues
- Emits: `ShopOpen(timestamp)`

**Important:**
- Only you (owner) can open the shop
- Opening doesn't affect existing orders
- Buyers with active refund windows keep their rights

### Closing the Shop

```solidity
shop.closeShop();
```

**When to close:**
- When planning a full withdrawal
- During maintenance or inventory updates
- When you need liquidity access
- End of business cycle (e.g., weekly/monthly)

**What happens:**
- Shop status changes to closed
- New orders are blocked
- Existing orders remain valid
- Refund windows continue for existing buyers
- Emits: `ShopClosed(timestamp)`

**Strategic uses:**
1. **Planned Withdrawal:**
   ```
   Friday 6 PM: Close shop
   Saturday: Wait for lastBuy + 24 hours
   Sunday: Withdraw everything
   Monday: Reopen
   ```

2. **Emergency Pause:**
   ```
   Issue detected: Close shop immediately
   Fix issue
   Reopen when ready
   ```

3. **Inventory Maintenance:**
   ```
   Week 1-4: Shop open
   Weekend: Close for "restocking"
   Withdraw accumulated funds
   Monday: Reopen with new cycle
   ```

### Checking Shop Status

```solidity
bool isClosed = shop.shopClosed();
```

---

## 💰 Understanding Withdrawals

### The Withdrawal Rules

Your ability to withdraw depends on **when the last order was placed:**

```solidity
uint256 lastBuy = shop.lastBuy();
uint256 refundPolicy = shop.REFUND_POLICY(); // 24 hours

if (block.timestamp > lastBuy + refundPolicy) {
    // FULL WITHDRAWAL MODE
    // Can withdraw everything
} else {
    // PARTIAL WITHDRAWAL MODE
    // Can only withdraw 50% of unconfirmed amounts (once)
}
```

### Full Withdrawal Mode

**Requirements:**
- More than 24 hours since `lastBuy`
- No recent orders

**What you can withdraw:**
```
withdrawable = entire contract balance
```

**What happens:**
- All funds transferred to you
- `totalConfirmedAmount` reset to 0
- `partialWithdrawal` flag reset to false
- Contract balance becomes 0

**Example:**
```solidity
// Last order was Friday 10 PM
// Now it's Sunday 10 PM (48 hours later)
shop.withdraw();
// → Withdraw everything ✅
```

### Partial Withdrawal Mode

**Requirements:**
- Within 24 hours of `lastBuy`
- Haven't done partial withdrawal yet this period

**What you can withdraw:**
```
confirmedAmount = totalConfirmedAmount (locked!)
unconfirmedAmount = balance - confirmedAmount
withdrawable = unconfirmedAmount × 50%
```

**What happens:**
- Only 50% of unconfirmed amounts transferred
- Confirmed amounts stay locked
- `partialWithdrawal` flag set to true
- Cannot withdraw again until full withdrawal mode

**Example:**
```solidity
// Contract has 10 ETH
// - 6 ETH confirmed (locked)
// - 4 ETH unconfirmed
// Last order was 2 hours ago

shop.withdraw();
// → Withdraw 2 ETH (50% of 4 ETH) ✅
// → 8 ETH remains in contract
// → Cannot withdraw again until 24+ hours after lastBuy
```

### The `partialWithdrawal` Flag

This prevents you from repeatedly draining funds:

```solidity
if (partialWithdrawal) {
    revert WaitUntilRefundPeriodPassed();
}
```

**Reset conditions:**
- Automatically resets in full withdrawal mode
- Cannot be manually reset
- One partial withdrawal per refund period

### Visual Example

```
Timeline: Orders coming in throughout the week

Mon 9 AM: Order arrives (lastBuy = Mon 9 AM)
Mon 10 AM: Order arrives (lastBuy = Mon 10 AM)
Mon 11 AM: Order arrives (lastBuy = Mon 11 AM)
...continuous orders...
Tue 9 AM: You try to withdraw
  → Partial mode (lastBuy was Tue 8 AM, only 1 hour ago)
  → Can withdraw 50% of unconfirmed (once)

Tue 10 AM: You try to withdraw again
  → Reverts! partialWithdrawal = true

Wed 9 AM: More orders keep coming (lastBuy keeps updating)
  → Still in partial mode
  → Cannot withdraw (already did partial)

[You decide to close shop]
Wed 6 PM: Close shop
Thu 6 PM: Wait 24 hours after last order
Thu 7 PM: Withdraw everything
  → Full mode (24+ hours since lastBuy)
  → Get all remaining funds ✅
```

---

## 📊 Withdrawal Strategies

### Strategy 1: The Patient Accumulator

**Best for:** Long-term growth, building large treasury

```
Approach:
- Keep shop open continuously
- Accept locked liquidity
- Do occasional partial withdrawals for expenses
- Plan major withdrawal once per quarter/year

Timeline:
Month 1-3: Open, continuous sales
- Revenue: 100 ETH accumulated
- Partial withdrawals: 20 ETH taken
- Locked: 80 ETH

Month 4: Need major capital
- Close shop for 48 hours
- Withdraw all 80 ETH
- Reopen and continue
```

**Pros:**
- ✅ Maximum revenue (always open)
- ✅ Builds customer trust (always available)
- ✅ Large lump sum withdrawals
- ✅ Simple to manage

**Cons:**
- ❌ Liquidity locked for long periods
- ❌ Must plan for capital needs
- ❌ Risk if you need emergency funds

**Best for owners who:**
- Have other income sources
- Can wait for returns
- Focus on growth over cash flow
- Want to build reputation

### Strategy 2: The Weekly Closer

**Best for:** Regular cash flow needs, medium-term planning

```
Approach:
- Open shop Mon-Fri (5 days)
- Close shop Fri evening
- Withdraw on Sunday
- Reopen Monday morning

Weekly Cycle:
Mon-Fri: Open
- ~50 orders
- ~5 ETH accumulated

Fri 6 PM: Close shop
Sat: Wait period
Sun 10 AM: Withdraw all (~5 ETH)
Sun 6 PM: Reopen

Monthly: ~20 ETH withdrawn
```

**Pros:**
- ✅ Regular weekly income
- ✅ Predictable cash flow
- ✅ Shop still feels "always available"
- ✅ Easy to plan around

**Cons:**
- ❌ Lose weekend sales
- ❌ Customers notice closure pattern
- ❌ Less total revenue than full-time

**Best for owners who:**
- Need regular income
- Have weekly expenses
- Can plan business around schedule
- Prefer predictability

### Strategy 3: The Opportunist

**Best for:** Flexible operations, maximizing both revenue and liquidity

```
Approach:
- Keep shop open most of the time
- Do partial withdrawals when needed
- Close shop only for major needs
- Adapt based on order flow

Dynamic Management:
Slow week:
- Few orders
- Can do full withdrawal after 24 hours
- Take opportunity

Busy week:
- Many orders
- Do partial withdrawal for expenses
- Keep accumulating
- Wait for slow period to do full withdrawal
```

**Pros:**
- ✅ Maximizes revenue during busy times
- ✅ Takes advantage of slow periods
- ✅ Flexible cash flow
- ✅ Responds to market conditions

**Cons:**
- ❌ Requires active management
- ❌ Unpredictable withdrawal schedule
- ❌ Need to monitor lastBuy timing
- ❌ More complex planning

**Best for owners who:**
- Can actively manage the shop
- Have variable capital needs
- Understand the timing mechanics
- Want to optimize for both metrics

### Strategy 4: The Bootstrapper

**Best for:** Starting with low capital, reinvesting heavily

```
Approach:
- Minimize withdrawals
- Reinvest in marketing/inventory
- Build large balance
- Major withdrawal for scaling

6-Month Plan:
Month 1-6: Keep shop open
- Do partial withdrawals only for critical needs
- Reinvest in growth
- Build up 50+ ETH balance

Month 6: Ready to scale
- Close shop for a week
- Withdraw accumulated funds
- Use capital for major upgrade
- Reopen with new capacity
```

**Pros:**
- ✅ Rapid growth potential
- ✅ Compounds returns
- ✅ Shows commitment to buyers
- ✅ Builds large treasury

**Cons:**
- ❌ No regular income
- ❌ High risk if business fails
- ❌ Requires outside income source
- ❌ Long wait for liquidity

**Best for owners who:**
- Have outside funding
- Believe in long-term vision
- Can delay gratification
- Want maximum growth rate

---

## 📈 Business Planning

### Understanding Your Cash Flow

#### Revenue Calculation
```
Per Order Revenue = PRICE + TAX
Example: 0.01 ETH + 0.001 ETH = 0.011 ETH

Daily Revenue (10 orders) = 0.11 ETH
Weekly Revenue = 0.77 ETH
Monthly Revenue = ~3.3 ETH
```

#### Withdrawal Projections

**Scenario A: Always Open**
```
Month 1:
- Revenue: 3.3 ETH
- Partial withdrawal (week 2): ~0.8 ETH
- Locked: 2.5 ETH

Months 1-6:
- Revenue: 19.8 ETH
- Partial withdrawals: ~5 ETH
- Locked: 14.8 ETH

Month 6 Closure:
- Withdraw: 14.8 ETH
- Total withdrawn: 19.8 ETH ✅
```

**Scenario B: Weekly Closures**
```
Month 1:
- Week 1: 0.77 ETH → Withdraw 0.77 ETH
- Week 2: 0.77 ETH → Withdraw 0.77 ETH
- Week 3: 0.77 ETH → Withdraw 0.77 ETH
- Week 4: 0.77 ETH → Withdraw 0.77 ETH
- Total: 3.08 ETH

Months 1-6:
- Weekly withdrawals: ~18.5 ETH
- No major lockup
```

**Comparison:**
| Strategy | Month 6 Total | Liquidity | Revenue Lost |
|----------|---------------|-----------|--------------|
| Always Open | 19.8 ETH | Low initially, high at withdrawal | 0 ETH (no closures) |
| Weekly Close | 18.5 ETH | High (weekly) | 1.3 ETH (weekend closures) |

### Tax & Accounting

**On-Chain Revenue Tracking:**
```solidity
// Total revenue ever
uint256 lifetimeRevenue = 0;
for each order:
    lifetimeRevenue += order.amount;

// Current balance
uint256 currentBalance = address(shop).balance;

// Total withdrawn (off-chain tracking)
uint256 withdrawn = lifetimeRevenue - currentBalance;
```

**For Tax Purposes:**
- Track all withdrawals (timestamps + amounts)
- Track refunds processed
- Calculate net revenue
- Consider consulting tax professional for crypto income

### Growth Metrics

**Track these KPIs:**
1. **Order Count:** `shop.nonces(buyers)` for each buyer
2. **Total Revenue:** Sum of all orders
3. **Refund Rate:** (Refunds / Orders) × 100%
4. **Average Order Value:** Total Revenue / Order Count
5. **Confirmation Rate:** (Confirmed Orders / Total Orders) × 100%
6. **Return Rate:** Regular buyers placing multiple orders

**Good Benchmarks:**
- Refund rate < 10% (shows happy customers)
- Confirmation rate > 70% (shows trust)
- Return rate > 30% (shows loyalty)

---

## 🔄 Ownership Transfer

### The 2-Step Process

Ownership transfer requires **two transactions** for safety:

#### Step 1: Initiate Transfer (Current Owner)

```solidity
shop.transferOwnership(payable(newOwnerAddress));
```

**What happens:**
- New owner set as `pendingOwner`
- You remain the owner
- Emits: `OwnershipTransferInitiated(you, newOwner)`

**Safety check:**
- Cannot transfer to zero address
- Cannot transfer to yourself

#### Step 2: Accept Transfer (New Owner)

```solidity
shop.acceptOwnership();
```

**What happens:**
- Caller becomes new owner
- `pendingOwner` reset to zero
- Previous owner loses all privileges
- Emits: `OwnershipTransferred(previousOwner, newOwner)`

**Requirements:**
- Must be called by `pendingOwner`
- Cannot be called by anyone else

### Canceling a Transfer

If you change your mind:

```solidity
shop.cancelOwnershipTransfer();
```

**What happens:**
- `pendingOwner` reset to zero
- You remain owner
- Transfer process canceled

### Transfer Best Practices

#### Before Transfer:
1. **Withdraw all funds**
   ```solidity
   // Close shop
   shop.closeShop();

   // Wait 24+ hours

   // Withdraw everything
   shop.withdraw();
   ```

2. **Document existing orders**
   - List all active orders
   - Note any unprocessed refunds
   - Track `totalConfirmedAmount`

3. **Communicate with buyers**
   - Announce ownership change
   - Assure continuation of service
   - Provide new owner contact

#### During Transfer:
1. **Verify new owner address** (multiple times!)
2. **Initiate transfer**
3. **Wait for new owner to accept**
4. **Verify transfer completed**

#### After Transfer:
1. **New owner tests access:**
   ```solidity
   // Try owner functions
   shop.openShop();
   shop.closeShop();
   ```

2. **Previous owner verifies loss of access:**
   ```solidity
   // Should revert
   shop.openShop(); // → UnauthorizedAccess
   ```

### Transfer Scenarios

**Scenario 1: Selling the Business**
```
1. Negotiate with buyer
2. Agree on handover date
3. Close shop, withdraw funds
4. Transfer ownership
5. Buyer accepts
6. Buyer reopens shop
```

**Scenario 2: Multi-Sig Upgrade**
```
1. Deploy multi-sig wallet
2. Transfer ownership to multi-sig
3. Multi-sig accepts
4. Now requires multiple signatures for operations
```

**Scenario 3: Business Partner Addition**
```
1. Create shared ownership contract
2. Transfer to shared contract
3. Both partners can manage through contract
4. Implement profit sharing logic
```

---

## ✅ Best Practices

### Daily Operations

**Morning Routine:**
1. Check shop status: `shop.shopClosed()`
2. Check recent orders: Look for new `BuyOrder` events
3. Check refund requests: Look for `RefundProcessed` events
4. Review `totalConfirmedAmount`
5. Calculate current locked/unlocked amounts

**Evening Routine:**
1. Review day's sales
2. Check if partial withdrawal available
3. Plan next day/week strategy
4. Update off-chain records
5. Monitor for any issues

### Weekly Planning

**Monday:**
- Review last week's metrics
- Plan withdrawal strategy
- Set goals for the week

**Friday:**
- Decide: Keep open or close for withdrawal?
- If closing: Prepare communication
- If staying open: Plan partial withdrawal

**Sunday:**
- Execute planned withdrawals
- Review cash flow
- Prepare for new week

### Security Practices

**Protect Your Private Key:**
- ✅ Use hardware wallet
- ✅ Never share private key
- ✅ Use multi-sig for large operations
- ✅ Test with small amounts first
- ❌ Never store key on internet-connected device

**Smart Contract Interactions:**
- ✅ Always verify contract address
- ✅ Double-check function parameters
- ✅ Test on testnet first
- ✅ Understand gas costs
- ❌ Never rush transactions

**Business Operations:**
- ✅ Keep detailed records
- ✅ Monitor for suspicious activity
- ✅ Respond quickly to buyer concerns
- ✅ Build reputation gradually
- ❌ Over-promise on refunds (terms are fixed)

### Customer Service

**Even though it's "trustless":**
- Communicate clearly about terms
- Respond to questions (off-chain)
- Build brand reputation
- Consider providing more than 24 hours notice for closures
- Be transparent about withdrawal schedules

**Reputation Building:**
- Consistent uptime
- Honor all refund requests (automatic anyway)
- Quick delivery of services
- Clear product descriptions
- Responsive communication channels

---

## ⚠️ Risk Management

### Liquidity Risks

**Problem:** Funds locked during busy periods

**Mitigation:**
1. Keep emergency funds outside contract
2. Plan withdrawal windows in advance
3. Do partial withdrawals for critical needs
4. Consider closing shop during emergencies
5. Don't rely solely on contract funds for operations

### Smart Contract Risks

**Problem:** Bugs or vulnerabilities (always possible)

**Mitigation:**
1. Contract has been tested (74 tests)
2. Use at your own risk
3. Start with small amounts
4. Monitor for unusual activity
5. Have exit strategy ready

### Buyer Refund Exploitation

**Problem:** Buyers could abuse refund system

**Reality:**
- Buyers only get 50% back (they lose 50%)
- 24-hour window is strict
- One refund per order
- Economic disincentive to abuse

**Mitigation:**
- Track refund rates
- If too high, consider business model
- Cannot prevent refunds (by design)
- Factor into pricing strategy

### Owner Key Compromise

**Problem:** Private key stolen

**Immediate Actions:**
1. Transfer ownership to secure address (if possible)
2. Withdraw all funds to secure address
3. Close shop
4. Communicate with buyers
5. Deploy new contract if necessary

**Prevention:**
- Use hardware wallet
- Multi-sig for large operations
- Regular security audits of key management
- Never expose key online

### Market Volatility

**Problem:** ETH price changes affect real-world value

**Mitigation:**
1. Regular withdrawals reduce exposure
2. Convert to stablecoin immediately if needed
3. Price items accounting for volatility
4. Accept that crypto business has this risk

---

## 🔧 Technical Reference

### Owner Functions

#### `withdraw()`
Withdraws available funds based on time since lastBuy.
```solidity
function withdraw() public onlyOwner
```
- **Full mode:** Withdraws everything (24+ hours since lastBuy)
- **Partial mode:** Withdraws 50% of unconfirmed, once per period
- **Reverts if:** Already did partial withdrawal this period

#### `openShop()`
Opens the shop for orders.
```solidity
function openShop() public onlyOwner
```
- **Emits:** `ShopOpen(timestamp)` (only if was closed)
- **Effect:** Sets `shopClosed = false`

#### `closeShop()`
Closes the shop, blocking new orders.
```solidity
function closeShop() public onlyOwner
```
- **Emits:** `ShopClosed(timestamp)`
- **Effect:** Sets `shopClosed = true`

#### `transferOwnership(newOwner)`
Initiates ownership transfer.
```solidity
function transferOwnership(address payable newOwner) public onlyOwner
```
- **Requires:** newOwner ≠ 0x0, newOwner ≠ current owner
- **Emits:** `OwnershipTransferInitiated(owner, newOwner)`
- **Effect:** Sets `pendingOwner = newOwner`

#### `acceptOwnership()`
Accepts pending ownership transfer.
```solidity
function acceptOwnership() public
```
- **Requires:** msg.sender == pendingOwner
- **Emits:** `OwnershipTransferred(previousOwner, newOwner)`
- **Effect:** Transfers ownership, resets pendingOwner

#### `cancelOwnershipTransfer()`
Cancels pending ownership transfer.
```solidity
function cancelOwnershipTransfer() public onlyOwner
```
- **Requires:** pendingOwner ≠ 0x0
- **Emits:** `OwnershipTransferInitiated(owner, 0x0)`
- **Effect:** Resets `pendingOwner = 0x0`

### Key State Variables

| Variable | Description | Visibility |
|----------|-------------|------------|
| `owner` | Current owner address | `public` |
| `pendingOwner` | Pending owner (during transfer) | `public` |
| `shopClosed` | Whether shop is closed | `public` |
| `lastBuy` | Timestamp of last purchase | `internal` |
| `partialWithdrawal` | Whether partial withdrawal done | `public` |
| `totalConfirmedAmount` | Sum of confirmed orders | `public` |

### View Functions (For Monitoring)

```solidity
// Check if you're the owner
address currentOwner = shop.owner();
require(currentOwner == msg.sender, "Not owner");

// Check shop status
bool closed = shop.shopClosed();

// Check confirmed amount
uint256 confirmed = shop.totalConfirmedAmount();

// Check partial withdrawal status
bool partialDone = shop.partialWithdrawal();

// Calculate withdrawable amount (off-chain)
uint256 balance = address(shop).balance;
uint256 unconfirmed = balance - confirmed;
uint256 withdrawable = (lastBuy + 24 hours < now) ? balance : unconfirmed * 50 / 100;
```

### Gas Costs (Approximate)

| Function | Gas Cost | USD @ 30 gwei, $3000 ETH |
|----------|----------|---------------------------|
| `withdraw()` | ~50,000 | ~$4.50 |
| `openShop()` | ~30,000 | ~$2.70 |
| `closeShop()` | ~30,000 | ~$2.70 |
| `transferOwnership()` | ~50,000 | ~$4.50 |
| `acceptOwnership()` | ~50,000 | ~$4.50 |

---

## ❓ Frequently Asked Questions

### **Q: Can I change the price after deployment?**
**A:** No. PRICE, TAX, REFUND_RATE, and REFUND_POLICY are immutable. Plan carefully before deployment.

### **Q: What if I need funds urgently but orders keep coming?**
**A:** Close the shop immediately. Wait 24 hours after the last order, then withdraw everything.

### **Q: Can I prevent buyers from refunding?**
**A:** No. The 24-hour refund window is guaranteed by the contract. This is a feature, not a bug - it builds trust.

### **Q: What happens if I lose my private key?**
**A:** All funds are permanently locked. There is NO recovery mechanism. Use hardware wallet and backups.

### **Q: Can I deploy multiple shops?**
**A:** Yes! Deploy as many contracts as you want. Each is independent with its own balance and rules.

### **Q: How do I handle taxes on crypto income?**
**A:** Consult a tax professional. Generally, income when withdrawn is taxable. Keep detailed records of all withdrawals.

### **Q: What if a buyer disputes after confirming?**
**A:** They can still refund within 24 hours. Confirmation doesn't waive their refund rights - it just helps your cash flow timing.

### **Q: Can I do multiple partial withdrawals?**
**A:** No. Only ONE partial withdrawal per refund period. After that, you must wait for full withdrawal mode.

### **Q: What if I transfer ownership by mistake?**
**A:** You can cancel if the new owner hasn't accepted yet. If they accepted, ownership is transferred permanently.

### **Q: How do I calculate my real profit?**
**A:**
```
Total Revenue = Sum of all orders
Total Refunded = Sum of all refunds
Gross Profit = Total Revenue - Total Refunded
Net Profit = Gross Profit - Gas Costs - Other Expenses
```

### **Q: Should I keep the shop always open or close regularly?**
**A:** Depends on your needs:
- Need regular income? → Close weekly
- Building long-term? → Stay open, do quarterly closures
- Flexible? → Opportunistic approach

### **Q: What's the optimal withdrawal frequency?**
**A:** There's no universal answer. Consider:
- Your capital needs
- Gas costs (frequent withdrawals = more gas)
- Customer perception (too many closures = unreliable)
- Growth goals (more closures = less revenue)

---

## 📞 Support & Resources

### Contract Information
- **Source Code:** [GitHub Repository]
- **Solidity Version:** 0.8.30
- **License:** MIT
- **Test Coverage:** 74 tests, 100% pass rate

### Owner Dashboard (Recommended Tools)
- **Etherscan:** Monitor transactions and events
- **Dune Analytics:** Track revenue and metrics
- **Safe (Gnosis):** Multi-sig wallet for security
- **Hardware Wallet:** Ledger or Trezor for key storage

### Community
- **Discord:** [Community link]
- **Twitter:** [Updates and announcements]
- **Documentation:** [Full technical docs]

---

## 🎯 Final Thoughts

### Success Principles

**1. Patience is Profit**
The system rewards patient, long-term thinking. Locked liquidity is the price of buyer trust.

**2. Transparency Builds Trust**
Even though the contract is trustless, communication builds reputation and repeat business.

**3. Plan Your Cash Flow**
Don't let locked funds surprise you. Plan withdrawal windows in advance.

**4. Security First**
Your private key is your business. Lose it = lose everything. No recovery possible.

**5. Adapt Your Strategy**
Different stages of business need different approaches:
- **Early:** Prioritize growth, accept locked funds
- **Established:** Optimize for cash flow, regular withdrawals
- **Scaling:** Build large treasury, strategic big withdrawals

### Your Business Model

This contract enforces a specific model:
- 24-hour refund guarantee (50% back)
- Time-locked withdrawals during active periods
- Full customer protection

**This is a feature, not a limitation.**

It creates a trust-minimized marketplace where:
- Buyers feel safe
- You can't exit scam
- Game theory aligns incentives
- Reputation matters

### Long-Term Vision

Think of locked liquidity as:
- Working capital
- Customer trust fund
- Growth investment
- Future big payday

The most successful on-chain shops will be those that embrace the model, plan accordingly, and build genuine value for customers.

**Good luck with your shop! 🚀**

---

*Last Updated: 2025-12-20*
*Contract Version: 1.0.0*
*Documentation Version: 1.0.0*
