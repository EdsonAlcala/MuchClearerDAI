/// liquidator.sol -- Collateral auction

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
    function flux(bytes32,address,address,uint) external;
}

/*
   This thing lets you liquidator some gems for a given amount of dai.
   Once the given amount of dai is raised, gems are forgone instead.

 - `tokensForSale` gems for sale
 - `tab` total dai wanted
 - `bid` dai paid
 - `daiIncomeReceiver` receives dai income
 - `usr` receives tokenCollateral forgone
 - `singleBidLifetime` single bid lifetime
 - `minimumBidIncrease` minimum bid increase
 - `end` max auction duration
*/

contract Flipper is LogEmitter, Permissioned {

    // --- Data ---
    struct Bid {
        uint256 bid;
        uint256 tokensForSale;
        address guy;  // high bidder
        uint48  tic;  // expiry time
        uint48  end;
        address usr;
        address daiIncomeReceiver;
        uint256 tab;
    }

    mapping (uint => Bid) public bids;

    CDPEngineContract public   CDPEngine;
    bytes32 public   ilk;

    uint256 constant ONE = 1.00E18;
    uint256 public   minimumBidIncrease = 1.05E18;  // 5% minimum bid increase
    uint48  public   singleBidLifetime = 3 hours;  // 3 hours bid duration
    uint48  public   tau = 2 days;   // 2 days total auction length
    uint256 public kicks = 0;

    // --- Events ---
    event Kick(
      uint256 id,
      uint256 tokensForSale,
      uint256 bid,
      uint256 tab,
      address indexed usr,
      address indexed daiIncomeReceiver
    );

    // --- Init ---
    constructor(address CDPEngine_, bytes32 ilk_) public {
        CDPEngine = CDPEngineContract(CDPEngine_);
        ilk = ilk_;
        authorizedAccounts[msg.sender] = true;
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
        else revert("Flipper/file-unrecognized-param");
    }

    // --- Auction ---
    function kick(address usr, address daiIncomeReceiver, uint tab, uint tokensForSale, uint bid)
        public onlyOwners returns (uint id)
    {
        require(kicks < uint(-1), "Flipper/overflow");
        id = ++kicks;

        bids[id].bid = bid;
        bids[id].tokensForSale = tokensForSale;
        bids[id].guy = msg.sender; // configurable??
        bids[id].end = add(uint48(now), tau);
        bids[id].usr = usr;
        bids[id].daiIncomeReceiver = daiIncomeReceiver;
        bids[id].tab = tab;

        CDPEngine.flux(ilk, msg.sender, address(this), tokensForSale);

        emit Kick(id, tokensForSale, bid, tab, usr, daiIncomeReceiver);
    }
    function tick(uint id) external emitLog {
        require(bids[id].end < now, "Flipper/not-finished");
        require(bids[id].tic == 0, "Flipper/bid-already-placed");
        bids[id].end = add(uint48(now), tau);
    }
    function tend(uint id, uint tokensForSale, uint bid) external emitLog {
        require(bids[id].guy != address(0), "Flipper/guy-not-set");
        require(bids[id].tic > now || bids[id].tic == 0, "Flipper/already-finished-tic");
        require(bids[id].end > now, "Flipper/already-finished-end");

        require(tokensForSale == bids[id].tokensForSale, "Flipper/tokensForSale-not-matrateAccumulatorng");
        require(bid <= bids[id].tab, "Flipper/higher-than-tab");
        require(bid >  bids[id].bid, "Flipper/bid-not-higher");
        require(mul(bid, ONE) >= mul(minimumBidIncrease, bids[id].bid) || bid == bids[id].tab, "Flipper/insufficient-increase");

        CDPEngine.move(msg.sender, bids[id].guy, bids[id].bid);
        CDPEngine.move(msg.sender, bids[id].daiIncomeReceiver, bid - bids[id].bid);

        bids[id].guy = msg.sender;
        bids[id].bid = bid;
        bids[id].tic = add(uint48(now), singleBidLifetime);
    }
    function dent(uint id, uint tokensForSale, uint bid) external emitLog {
        require(bids[id].guy != address(0), "Flipper/guy-not-set");
        require(bids[id].tic > now || bids[id].tic == 0, "Flipper/already-finished-tic");
        require(bids[id].end > now, "Flipper/already-finished-end");

        require(bid == bids[id].bid, "Flipper/not-matrateAccumulatorng-bid");
        require(bid == bids[id].tab, "Flipper/tend-not-finished");
        require(tokensForSale < bids[id].tokensForSale, "Flipper/tokensForSale-not-lower");
        require(mul(minimumBidIncrease, tokensForSale) <= mul(bids[id].tokensForSale, ONE), "Flipper/insufficient-decrease");

        CDPEngine.move(msg.sender, bids[id].guy, bid);
        CDPEngine.flux(ilk, address(this), bids[id].usr, bids[id].tokensForSale - tokensForSale);

        bids[id].guy = msg.sender;
        bids[id].tokensForSale = tokensForSale;
        bids[id].tic = add(uint48(now), singleBidLifetime);
    }
    function deal(uint id) external emitLog {
        require(bids[id].tic != 0 && (bids[id].tic < now || bids[id].end < now), "Flipper/not-finished");
        CDPEngine.flux(ilk, address(this), bids[id].guy, bids[id].tokensForSale);
        delete bids[id];
    }

    function yank(uint id) external emitLog onlyOwners {
        require(bids[id].guy != address(0), "Flipper/guy-not-set");
        require(bids[id].bid < bids[id].tab, "Flipper/already-dent-phase");
        CDPEngine.flux(ilk, address(this), msg.sender, bids[id].tokensForSale);
        CDPEngine.move(msg.sender, bids[id].guy, bids[id].bid);
        delete bids[id];
    }
}
