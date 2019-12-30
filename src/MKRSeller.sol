/// flop.sol -- Debt auction

// Copyright (C) 2018 Rain <rainbreak@riseup.net>
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

pragma solidity 0.5.12;

import "./commonFunctions.sol";

contract CDPEngineContract {
    function move(address,address,uint) external;
    function suck(address,address,uint) external;
}
contract SimpleToken {
    function mint(address,uint) external;
}

/*
   This thing creates MKR on demand in return for dai.

 - `mkrAmount` MKR for sale
 - `bid` dai paid
 - `gal` receives dai income
 - `ttl` single bid lifetime
 - `beg` minimum bid increase
 - `end` max auction duration
*/

contract MKRSeller is LogEmitter {
    // --- Auth ---
    mapping (address => uint) public authorizedAccounts;
    function addAuthorization(address usr) external emitLog onlyOwners { authorizedAccounts[usr] = 1; }
    function removeAuthorization(address usr) external emitLog onlyOwners { authorizedAccounts[usr] = 0; }
    modifier onlyOwners {
        require(authorizedAccounts[msg.sender] == 1, "MKRSeller/not-onlyOwnersorized");
        _;
    }

    // --- Data ---
    struct Auction {
        uint256 daiAmount; //in dai
        uint256 mkrAmount;
        address highestBidder;  // high bidder
        uint48  endTime;  // this gets pushed back every time there is a new bid
        uint48  maxEndTime;
    }

    mapping (uint => Auction) public auctions;

    CDPEngineContract  public   CDPEngine;
    SimpleToken  public  MKRToken;

    uint256  constant ONE = 1.00E18;
    uint256  public   minBidDecreaseMultiplier = 1.05E18;  // 5% minimum daiAmount increase
    uint256  public   mkrAmountMultiplierOnReopen = 1.50E18;  // 50% mkrAmount increase for reopen
    uint48   public   timeIncreasePerBid = 3 hours;  // 3 hours bid lifetime
    uint48   public   auctionLength = 2 days;   // 2 days total auction length
    uint256  public auctionCount = 0;
    uint256  public DSRisActive;
    address  public debtEngine;  // not used until shutdown

    // --- Events ---
    event Kick(
      uint256 id,
      uint256 mkrAmount,
      uint256 bid,
      address indexed gal
    );

    // --- Init ---
    constructor(address CDPEngine_, address token_) public {
        authorizedAccounts[msg.sender] = 1;
        CDPEngine = CDPEngineContract(CDPEngine_);
        MKRToken = SimpleToken(token_);
        DSRisActive = 1;
    }

    // --- Math ---
    function add(uint48 x, uint48 y) internal pure returns (uint48 z) {
        require((z = x + y) >= x);
    }
    function mul(uint x, uint y) internal pure returns (uint z) {
        require(y == 0 || (z = x * y) / y == x);
    }

    // --- Admin ---
    function setVariable(bytes32 variableName, uint data) external emitLog onlyOwners {
        if (variableName == "minBidDecreaseMultiplier") minBidDecreaseMultiplier = data;
        else if (variableName == "mkrAmountMultiplierOnReopen") mkrAmountMultiplierOnReopen = data;
        else if (variableName == "timeIncreasePerBid") timeIncreasePerBid = uint48(data);
        else if (variableName == "auctionLength") auctionLength = uint48(data);
        else revert("MKRSeller/file-unrecognized-param");
    }

    // --- Auction ---
    function newAuction(address bidder, uint mkrAmount, uint daiAmount) external onlyOwners returns (uint id) {
        require(DSRisActive == 1, "MKRSeller/not-DSRisActive");
        require(auctionCount < uint(-1), "MKRSeller/overflow");
        id = ++auctionCount;

        auctions[id].daiAmount = daiAmount;
        auctions[id].mkrAmount = mkrAmount;
        auctions[id].highestBidder = bidder;
        auctions[id].endTime = add(uint48(now), total);

        emit Kick(id, mkrAmount, bid, gal);
    }
    function reopenAuction(uint id) external emitLog {
        require(auctions[id].maxEndTime < now, "MKRSeller/not-finished");
        require(auctions[id].endTime == 0, "MKRSeller/bid-already-placed");
        auctions[id].mkrAmount = mul(pad, auctions[id].mkrAmount) / ONE;
        auctions[id].end = add(uint48(now), tau);
    }
    function bid(uint id, uint mkrAmount, uint daiAmount) external emitLog {
        require(DSRisActive == 1, "MKRSeller/not-DSRisActive");
        require(auctions[id].highestBidder != address(0), "MKRSeller/highestBidder-not-set");
        require(auctions[id].endTime > now || auctions[id].endTime == 0, "MKRSeller/already-finished-tic");
        require(auctions[id].maxEndTime > now, "MKRSeller/already-finished-end");

        require(daiAmount == auctions[id].daiAmount, "MKRSeller/not-matrateAccumulatorng-bid");
        require(mkrAmount <  auctions[id].mkrAmount, "MKRSeller/mkrAmount-not-lower");
        require(mul(minBidDecreaseMultiplier, mkrAmount) <= mul(auctions[id].mkrAmount, ONE), "MKRSeller/insufficient-decrease");

        CDPEngine.move(msg.sender, auctions[id].highestBidder, daiAmount);

        auctions[id].highestBidder = msg.sender;
        auctions[id].mkrAmount = mkrAmount;
        auctions[id].endTime = add(uint48(now), timeIncreasePerBid);
    }
    function finalizeAuction(uint id) external emitLog {
        require(DSRisActive == 1, "MKRSeller/not-DSRisActive");
        require(auctions[id].endTime != 0 && (auctions[id].endTime < now || auctions[id].maxEndTime < now), "MKRSeller/not-finished");
        MKRToken.mint(auctions[id].highestBidder, auctions[id].mkrAmount);
        delete auctions[id];
    }

    // --- Shutdown ---
    function cage() external emitLog onlyOwners {
       DSRisActive = 0;
       debtEngine = msg.sender;
    }
    function cancelAuction(uint id) external emitLog {
        require(DSRisActive == 0, "MKRSeller/still-DSRisActive");
        require(auctions[id].highestBidder != address(0), "MKRSeller/highestBidder-not-set");
        CDPEngine.suck(debtEngine, auctions[id].highestBidder, auctions[id].daiAmount);
        delete auctions[id];
    }
}
