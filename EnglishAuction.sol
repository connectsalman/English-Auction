// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC721 {
    function transferFrom(address from, address to, uint tokenId) external;
}

contract EnglishAuction {
    // events
    event Start(uint startTime, uint endTime);
    event Bid(address indexed bidder, uint value);
    event End(address highestBidder, uint value);
    event Withdraw(address indexed bidder, uint value);

    // auction state
    bool public started;
    bool public ended;
    uint public endTime;
    uint public highestBid;
    address public highestBidder;
    mapping(address => uint) public allBids;

    address payable public immutable owner;
    uint public immutable nftId;
    IERC721 public immutable nft;

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call the function");
        _;
    }

    constructor(address _nft, uint _nftId) {
        owner = payable(msg.sender);
        nft = IERC721(_nft);
        nftId = _nftId;
    }

    function bid() external payable {
        require(started, "Auction has not started");
        require(msg.value > highestBid, "Bid price is lower than the current highest bid");
        require(block.timestamp < endTime, "Auction has ended");

        // refund logic for the PREVIOUS highest bidder
        // (only if there was a real previous bidder, not address(0))
        if (highestBidder != address(0)) {
            allBids[highestBidder] += highestBid;
        }

        highestBid = msg.value;
        highestBidder = msg.sender;

        emit Bid(msg.sender, msg.value);
    }

    function start(uint _openingBid, uint _duration) external onlyOwner {
        require(!started, "Auction has already started");

        highestBid = _openingBid;
        endTime = block.timestamp + _duration;
        nft.transferFrom(owner, address(this), nftId);
        started = true;

        emit Start(block.timestamp, endTime);
    }

    function end() external onlyOwner {
        require(started, "Auction has not started");
        require(block.timestamp >= endTime, "Auction has not ended");
        require(!ended, "Auction has already ended");

        ended = true;
        nft.transferFrom(address(this), highestBidder, nftId);

        // FIXED: correct call syntax with {value: ...}
        (bool success, ) = owner.call{value: highestBid}("");
        require(success, "Transfer to owner failed");

        emit End(highestBidder, highestBid);
    }

    function withdraw() external {
        uint value = allBids[msg.sender];

        // checks-effects-interactions: zero out BEFORE sending
        allBids[msg.sender] = 0;

        if (value > 0) {
            // FIXED: send "value" to "msg.sender" (the actual caller)
            (bool success, ) = payable(msg.sender).call{value: value}("");
            require(success, "Transfer failed");
        }

        emit Withdraw(msg.sender, value);
    }
}