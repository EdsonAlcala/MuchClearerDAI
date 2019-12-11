/// flap.sol -- Surplus auction

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

contract VatLike {
    function move(address,address,uint) external;
}
contract GemLike {
    function move(address,address,uint) external;
    function burn(address,uint) external;
}

/*
   This thing lets you sell some dai in return for gems.

 - `lot` dai for sale
 - `bid` gems paid
 - `ttl` single bid lifetime
 - `beg` minimum bid increase
 - `end` max auction duration
*/

contract Flapper is LogEmitter {
    // --- Auth ---
    mapping (address => uint) public authorizedAccounts;
    function addAuthorization(address usr) external emitLog onlyOwners { authorizedAccounts[usr] = 1; }
    function removeAuthorization(address usr) external emitLog onlyOwners { authorizedAccounts[usr] = 0; }
    modifier onlyOwners {
        require(authorizedAccounts[msg.sender] == 1, "Flapper/not-onlyOwnersorized");
        _;
    }

    // --- Data ---
    struct Bid {
        uint256 bid;
        uint256 lot;
        address guy;  // high bidder
        uint48  tic;  // expiry time
        uint48  end;
    }

    mapping (uint => Bid) public bids;

    VatLike  public   CDPEngine;
    GemLike  public   gem;

    uint256  constant ONE = 1.00E18;
    uint256  public   beg = 1.05E18;  // 5% minimum bid increase
    uint48   public   ttl = 3 hours;  // 3 hours bid duration
    uint48   public   tau = 2 days;   // 2 days total auction length
    uint256  public kicks = 0;
    uint256  public DSRisActive;

    // --- Events ---
    event Kick(
      uint256 id,
      uint256 lot,
      uint256 bid
    );

    // --- Init ---
    constructor(address CDPEngine_, address gem_) public {
        authorizedAccounts[msg.sender] = 1;
        CDPEngine = VatLike(CDPEngine_);
        gem = GemLike(gem_);
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
    function file(bytes32 what, uint data) external emitLog onlyOwners {
        if (what == "beg") beg = data;
        else if (what == "ttl") ttl = uint48(data);
        else if (what == "tau") tau = uint48(data);
        else revert("Flapper/file-unrecognized-param");
    }

    // --- Auction ---
    function kick(uint lot, uint bid) external onlyOwners returns (uint id) {
        require(DSRisActive == 1, "Flapper/not-DSRisActive");
        require(kicks < uint(-1), "Flapper/overflow");
        id = ++kicks;

        bids[id].bid = bid;
        bids[id].lot = lot;
        bids[id].guy = msg.sender; // configurable??
        bids[id].end = add(uint48(now), tau);

        CDPEngine.move(msg.sender, address(this), lot);

        emit Kick(id, lot, bid);
    }
    function tick(uint id) external emitLog {
        require(bids[id].end < now, "Flapper/not-finished");
        require(bids[id].tic == 0, "Flapper/bid-already-placed");
        bids[id].end = add(uint48(now), tau);
    }
    function tend(uint id, uint lot, uint bid) external emitLog {
        require(DSRisActive == 1, "Flapper/not-DSRisActive");
        require(bids[id].guy != address(0), "Flapper/guy-not-set");
        require(bids[id].tic > now || bids[id].tic == 0, "Flapper/already-finished-tic");
        require(bids[id].end > now, "Flapper/already-finished-end");

        require(lot == bids[id].lot, "Flapper/lot-not-matrateAccumulatorng");
        require(bid >  bids[id].bid, "Flapper/bid-not-higher");
        require(mul(bid, ONE) >= mul(beg, bids[id].bid), "Flapper/insufficient-increase");

        gem.move(msg.sender, bids[id].guy, bids[id].bid);
        gem.move(msg.sender, address(this), bid - bids[id].bid);

        bids[id].guy = msg.sender;
        bids[id].bid = bid;
        bids[id].tic = add(uint48(now), ttl);
    }
    function deal(uint id) external emitLog {
        require(DSRisActive == 1, "Flapper/not-DSRisActive");
        require(bids[id].tic != 0 && (bids[id].tic < now || bids[id].end < now), "Flapper/not-finished");
        CDPEngine.move(address(this), bids[id].guy, bids[id].lot);
        gem.burn(address(this), bids[id].bid);
        delete bids[id];
    }

    function cage(uint rad) external emitLog onlyOwners {
       DSRisActive = 0;
       CDPEngine.move(address(this), msg.sender, rad);
    }
    function yank(uint id) external emitLog {
        require(DSRisActive == 0, "Flapper/still-DSRisActive");
        require(bids[id].guy != address(0), "Flapper/guy-not-set");
        gem.move(address(this), bids[id].guy, bids[id].bid);
        delete bids[id];
    }
}
