// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

//
//                                                  █████
//                                                 ░░███
//   ██████  █████ █████ █████████████       █████  ░███████    ██████  ████████
//  ███░░███░░███ ░░███ ░░███░░███░░███     ███░░   ░███░░███  ███░░███░░███░░███
// ░███████  ░███  ░███  ░███ ░███ ░███    ░░█████  ░███ ░███ ░███ ░███ ░███ ░███
// ░███░░░   ░░███ ███   ░███ ░███ ░███     ░░░░███ ░███ ░███ ░███ ░███ ░███ ░███
// ░░██████   ░░█████    █████░███ █████    ██████  ████ █████░░██████  ░███████
//  ░░░░░░     ░░░░░    ░░░░░ ░░░ ░░░░░    ░░░░░░  ░░░░ ░░░░░  ░░░░░░   ░███░░░
//                                                                      ░███
//                                                                      █████
//                                                                     ░░░░░
//

library Transaction {
    struct Order {
        address buyer;
        uint256 nonce;
        uint256 amount;
        uint256 date;
    }

    function addTax(uint256 amount, uint16 tax, uint16 base) internal pure returns (uint256) {
        return amount + (amount * tax / base);
    }

    function getRefund(uint256 amount, uint16 rate, uint16 base) internal pure returns (uint256) {
        return amount * rate / base;
    }
}

contract Shop {
    using Transaction for uint256;

    uint256 immutable PRICE;
    uint16 immutable TAX;
    uint16 immutable TAX_BASE;
    uint16 immutable REFUND_RATE;
    uint16 immutable REFUND_BASE;
    uint256 immutable REFUND_POLICY;
    address payable public owner;

    mapping(bytes32 => Transaction.Order) public orders;
    mapping(address => uint256) public nonces;
    mapping(bytes32 => bool) public refunds;
    uint256 lastBuy;
    bool partialWithdrawal;
    bool shopClosed;

    event BuyOrder(bytes32 orderId, uint256 amount);
    event RefundProcessed(bytes32 orderId, uint256 amount);
    event ShopOpen(uint256 timestamp);
    event ShopClosed(uint256 timestamp);

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

    constructor(uint256 price, uint16 tax, uint16 taxBase, uint16 refundRate, uint16 refundBase, uint256 refundPolicy) {
        // Validate price is non-zero
        if (price == 0) revert InvalidConstructorParameters();

        // Validate tax base to prevent division by zero
        if (taxBase == 0) revert InvalidConstructorParameters();

        // Validate tax doesn't exceed 100% (tax should be <= taxBase for sanity)
        if (tax > taxBase) revert InvalidConstructorParameters();

        // Validate refund base to prevent division by zero
        if (refundBase == 0) revert InvalidConstructorParameters();

        // Validate refund rate doesn't exceed 100% (refundRate should be <= refundBase)
        if (refundRate > refundBase) revert InvalidConstructorParameters();

        // Validate refund policy is non-zero (must have some refund window)
        if (refundPolicy == 0) revert InvalidConstructorParameters();

        // Validate owner is not zero address (though msg.sender should never be zero)
        if (msg.sender == address(0)) revert InvalidConstructorParameters();

        PRICE = price;
        TAX = tax;
        TAX_BASE = taxBase;
        REFUND_RATE = refundRate;
        REFUND_BASE = refundBase;
        REFUND_POLICY = refundPolicy;
        owner = payable(msg.sender);
    }

    modifier onlyOwner() {
        checkOwner();
        _;
    }

    function checkOwner() internal view {
        if (msg.sender != owner) revert UnauthorizedAccess();
    }

    function buy() public payable {
        if (shopClosed) revert ShopIsClosed();
        if (msg.value == PRICE) revert MissingTax();
        uint256 expectedTotal = PRICE.addTax(TAX, TAX_BASE);
        if (msg.value < expectedTotal) revert InsuffientAmount();
        if (msg.value > expectedTotal) revert ExcessAmount();
        uint256 nonce = nonces[msg.sender];
        bytes32 orderId = keccak256(abi.encode(msg.sender, nonce));
        nonces[msg.sender]++;
        orders[orderId] = Transaction.Order(msg.sender, nonce, PRICE, block.timestamp);
        lastBuy = block.timestamp;
        emit BuyOrder(orderId, msg.value);
    }

    function refund(bytes32 orderId) external {
        Transaction.Order memory order = orders[orderId];

        // Checks - validate order exists and caller is authorized
        if (order.buyer == address(0)) revert InvalidRefundBenefiary();
        if (order.buyer != msg.sender) revert InvalidRefundBenefiary();
        if (block.timestamp > order.date + REFUND_POLICY) revert RefundPolicyExpired();
        if (refunds[orderId]) revert DuplicateRefundClaim();

        // Effects - update state before external calls
        refunds[orderId] = true;
        uint256 refundAmount = PRICE.getRefund(REFUND_RATE, REFUND_BASE);

        // Interactions - external call last
        (bool success, ) = payable(msg.sender).call{value: refundAmount}("");
        require(success, "Refund transfer failed");
        emit RefundProcessed(orderId, refundAmount);
    }

    function withdraw() public onlyOwner {
        if (lastBuy + REFUND_POLICY < block.timestamp) {
            // Full withdrawal allowed - refund period has passed
            uint256 amount = address(this).balance;
            partialWithdrawal = false;
            (bool success, ) = owner.call{value: amount}("");
            require(success, "Withdrawal failed");
        } else {
            // Partial withdrawal only - refund period still active
            if (partialWithdrawal) revert WaitUntilRefundPeriodPassed();
            partialWithdrawal = true;
            uint256 amount = address(this).balance * REFUND_RATE / REFUND_BASE;
            (bool success, ) = owner.call{value: amount}("");
            require(success, "Withdrawal failed");
        }
    }

    function openShop() public onlyOwner {
        if (shopClosed) {
            shopClosed = false;
            emit ShopOpen(block.timestamp);
        }
    }

    function closeShop() public onlyOwner {
        shopClosed = true;
        emit ShopClosed(block.timestamp);
    }

    receive() external payable {}
}
