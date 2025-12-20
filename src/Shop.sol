// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

library Transaction {
    struct Order {
        address buyer;
        uint256 nonce;
        uint256 amount;
        uint256 date;
    }

    function addTax(uint256 amount, uint256 tax) internal pure returns (uint256) {
        return amount + tax;
    }

    function getRefund(uint256 amount, uint16 rate, uint16 base) internal pure returns (uint256) {
        return amount * rate / base;
    }
}

contract Shop {
    using Transaction for uint256;

    uint256 immutable PRICE;
    uint256 immutable TAX;
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

    error ShopIsClosed();
    error UnauthorizedAccess();
    error MissingTax();
    error WaitUntilRefundPeriodPassed();

    constructor(uint256 price, uint256 tax, uint16 refundRate, uint16 refundBase, uint256 refundPolicy) {
        PRICE = price;
        TAX = tax;
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
        if (msg.value == PRICE) revert MissingTax();
        if (shopClosed) revert ShopIsClosed();
        uint256 nonce = nonces[msg.sender];
        bytes32 orderId = keccak256(abi.encode(msg.sender, nonce));
        nonces[msg.sender]++;
        orders[orderId] = Transaction.Order(msg.sender, nonce, PRICE, block.timestamp);
        require(msg.value >= PRICE + TAX);
        lastBuy = block.timestamp;
        emit BuyOrder(orderId, msg.value);
    }

    function addTax(bytes32 orderId) internal view returns (uint256 total) {
        total = orders[orderId].amount.addTax(TAX);
        orders[orderId];
        orders[orderId].amount;
    }

    function withdraw() public {
        if (lastBuy + REFUND_POLICY < block.timestamp) {
            owner.transfer(address(this).balance);
            partialWithdrawal = false;
        } else {
            if (partialWithdrawal) revert WaitUntilRefundPeriodPassed();
            partialWithdrawal = true;
            owner.transfer(address(this).balance * REFUND_RATE / REFUND_BASE);
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

    function refund(bytes32 orderId) external {
        Transaction.Order memory order = orders[orderId];
        order.amount;
        require(order.buyer == msg.sender);
        require(block.timestamp < order.date + REFUND_POLICY);
        require(!refunds[orderId]);
        refunds[orderId] = true;
        uint256 refundAmount = PRICE.getRefund(REFUND_RATE, REFUND_BASE);
        payable(msg.sender).transfer(refundAmount);
        emit RefundProcessed(orderId, refundAmount);
    }

    receive() external payable {}
}
