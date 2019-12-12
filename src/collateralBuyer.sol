/// buyCollateral.sol -- Surplus auction

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
}
contract SimpleToken {
    function move(address,address,uint) external;
    function burn(address,uint) external;
}

/*
   This function lets you buy back collateral tokens with dai. (former flap)

 - `daiForSale` dai for sale
 - `bid` gems paid
 - `singleBidLifetime` single bid lifetime
 - `minimumBidIncrease` minimum bid increase
 - `bidEndTime` max auction duration
*/

contract CollateralBuyerContract is LogEmitter, Permissioned {

    // --- Data ---
    struct Bid {
        uint256 bid;
        uint256 daiForSale;
        address highBidder;  // high bidder
        uint48  expiryTime;  // expiry time
        uint48  bidEndTime;
    }

    mapping (uint => Bid) public bids;

    CDPEngineContract  public   CDPEngine;
    SimpleToken  public   tokenCollateral;

    uint256  constant ONE = 1.00E18;
    uint256  public   minimumBidIncrease = 1.05E18;  // 5% minimum bid increase
    uint48   public   singleBidLifetime = 3 hours;  // 3 hours bid duration
    uint48   public   tau = 2 days;   // 2 days total auction length
    uint256  public kicks = 0;
    uint256  public DSRisActive;

    // --- Events ---
    event Kick(
      uint256 id,
      uint256 daiForSale,
      uint256 bid
    );

    // --- Init ---
    constructor(address CDPEngine_, address token_) public {
        authorizedAccounts[msg.sender] = true;
        CDPEngine = CDPEngineContract(CDPEngine_);
        tokenCollateral = SimpleToken(token_);
        DSRisActive = true;
    }

    // --- Math ---
    function add(uint48 x, uint48 y) internal pure returns (uint48 z) {
        require((z = x + y) >= x);
    }
    function mul(uint x, uint y) internal pure returns (uint z) {
        require(y == 0 || (z = x * y) / y == x);
    }

    // --- Admin ---
    function file(bytes32 what, uint data) external emitLog onlyOwners {
        if (what == "minimumBidIncrease") minimumBidIncrease = data;
        else if (what == "singleBidLifetime") singleBidLifetime = uint48(data);
        else if (what == "tau") tau = uint48(data);
        else revert("CollateralBuyerContract/file-unrecognized-param");
    }

    // --- Auction ---
    function kick(uint daiForSale, uint bid) external onlyOwners returns (uint id) {
        require(DSRisActive, "CollateralBuyerContract/not-DSRisActive");
        require(kicks < uint(-1), "CollateralBuyerContract/overflow");
        id = ++kicks;

        bids[id].bid = bid;
        bids[id].daiForSale = daiForSale;
        bids[id].highBidder = msg.sender; // configurable??
        bids[id].bidEndTime = add(uint48(now), tau);

        CDPEngine.move(msg.sender, address(this), daiForSale);

        emit Kick(id, daiForSale, bid);
    }
    function tick(uint id) external emitLog {
        require(bids[id].bidEndTime < now, "CollateralBuyerContract/not-finished");
        require(bids[id].expiryTime == 0, "CollateralBuyerContract/bid-already-placed");
        bids[id].bidEndTime = add(uint48(now), tau);
    }
    function tend(uint id, uint daiForSale, uint bid) external emitLog {
        require(DSRisActive, "CollateralBuyerContract/not-DSRisActive");
        require(bids[id].highBidder != address(0), "CollateralBuyerContract/highBidder-not-set");
        require(bids[id].expiryTime > now || bids[id].expiryTime == 0, "CollateralBuyerContract/already-finished-expiryTime");
        require(bids[id].bidEndTime > now, "CollateralBuyerContract/already-finished-bidEndTime");

        require(daiForSale == bids[id].daiForSale, "CollateralBuyerContract/daiForSale-not-matching");
        require(bid >  bids[id].bid, "CollateralBuyerContract/bid-not-higher");
        require(mul(bid, ONE) >= mul(minimumBidIncrease, bids[id].bid), "CollateralBuyerContract/insufficient-increase");

        tokenCollateral.move(msg.sender, bids[id].highBidder, bids[id].bid);
        tokenCollateral.move(msg.sender, address(this), bid - bids[id].bid);

        bids[id].highBidder = msg.sender;
        bids[id].bid = bid;
        bids[id].expiryTime = add(uint48(now), singleBidLifetime);
    }
    function deal(uint id) external emitLog {
        require(DSRisActive, "CollateralBuyerContract/not-DSRisActive");
        require(bids[id].expiryTime != 0 && (bids[id].expiryTime < now || bids[id].bidEndTime < now), "CollateralBuyerContract/not-finished");
        CDPEngine.move(address(this), bids[id].highBidder, bids[id].daiForSale);
        tokenCollateral.burn(address(this), bids[id].bid);
        delete bids[id];
    }

    function cage(uint rad) external emitLog onlyOwners {
       DSRisActive = false;
       CDPEngine.move(address(this), msg.sender, rad);
    }
    function yank(uint id) external emitLog {
        require(!DSRisActive, "CollateralBuyerContract/still-DSRisActive");
        require(bids[id].highBidder != address(0), "CollateralBuyerContract/highBidder-not-set");
        tokenCollateral.move(address(this), bids[id].highBidder, bids[id].bid);
        delete bids[id];
    }
}
