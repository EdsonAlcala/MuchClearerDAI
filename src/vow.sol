/// debtEngine.sol -- Dai settlement module

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

contract FlopLike {
    function kick(address daiIncomeReceiver, uint tokensForSale, uint bid) external returns (uint);
    function cage() external;
    function DSRisActive() external returns (uint);
}

contract FlapLike {
    function kick(uint tokensForSale, uint bid) external returns (uint);
    function cage(uint) external;
    function DSRisActive() external returns (uint);
}

contract CDPEngineContract {
    function dai (address) external view returns (uint);
    function sin (address) external view returns (uint);
    function heal(uint256) external;
    function hope(address) external;
    function nope(address) external;
}

contract Vow is LogEmitter {
    // --- Auth ---
    mapping (address => uint) public authorizedAccounts;
    function addAuthorization(address usr) external emitLog onlyOwners { require(DSRisActive, "Vow/not-DSRisActive"); authorizedAccounts[usr] = 1; }
    function removeAuthorization(address usr) external emitLog onlyOwners { authorizedAccounts[usr] = false; }
    modifier onlyOwners {
        require(authorizedAccounts[msg.sender], "Vow/not-onlyOwnersorized");
        _;
    }

    // --- Data ---
    CDPEngineContract public CDPEngine;
    FlapLike public flapper;
    FlopLike public flopper;

    mapping (uint256 => uint256) public sin; // debt queue
    uint256 public Sin;   // queued debt          [rad]
    uint256 public Ash;   // on-auction debt      [rad]

    uint256 public wait;  // flop delay
    uint256 public dump;  // flop initial tokensForSale size  [amount]
    uint256 public sump;  // flop fixed bid size    [rad]

    uint256 public bump;  // buyCollateral fixed tokensForSale size    [rad]
    uint256 public hump;  // surplus buffer       [rad]

    bool public DSRisActive;

    // --- Init ---
    constructor(address CDPEngine_, address flapper_, address flopper_) public {
        authorizedAccounts[msg.sender] = true;
        CDPEngine     = CDPEngineContract(CDPEngine_);
        flapper = FlapLike(flapper_);
        flopper = FlopLike(flopper_);
        CDPEngine.hope(flapper_);
        DSRisActive = true;
    }

    // --- Math ---
    function add(uint x, uint y) internal pure returns (uint z) {
        require((z = x + y) >= x);
    }
    function sub(uint x, uint y) internal pure returns (uint z) {
        require((z = x - y) <= x);
    }
    function min(uint x, uint y) internal pure returns (uint z) {
        return x <= y ? x : y;
    }

    // --- Administration ---
    function file(bytes32 what, uint data) external emitLog onlyOwners {
        if (what == "wait") wait = data;
        else if (what == "bump") bump = data;
        else if (what == "sump") sump = data;
        else if (what == "dump") dump = data;
        else if (what == "hump") hump = data;
        else revert("Vow/file-unrecognized-param");
    }

    function file(bytes32 what, address data) external emitLog onlyOwners {
        if (what == "flapper") {
            CDPEngine.nope(address(flapper));
            flapper = FlapLike(data);
            CDPEngine.hope(data);
        }
        else if (what == "flopper") flopper = FlopLike(data);
        else revert("Vow/file-unrecognized-param");
    }

    // Push to debt-queue
    function fess(uint tab) external emitLog onlyOwners {
        sin[now] = add(sin[now], tab);
        Sin = add(Sin, tab);
    }
    // Pop from debt-queue
    function flog(uint era) external emitLog {
        require(add(era, wait) <= now, "Vow/wait-not-finished");
        Sin = sub(Sin, sin[era]);
        sin[era] = 0;
    }

    // Debt settlement
    function heal(uint rad) external emitLog {
        require(rad <= CDPEngine.dai(address(this)), "Vow/insufficient-surplus");
        require(rad <= sub(sub(CDPEngine.sin(address(this)), Sin), Ash), "Vow/insufficient-debt");
        CDPEngine.heal(rad);
    }
    function kiss(uint rad) external emitLog {
        require(rad <= Ash, "Vow/not-enough-ash");
        require(rad <= CDPEngine.dai(address(this)), "Vow/insufficient-surplus");
        Ash = sub(Ash, rad);
        CDPEngine.heal(rad);
    }

    // Debt auction
    function flop() external emitLog returns (uint id) {
        require(sump <= sub(sub(CDPEngine.sin(address(this)), Sin), Ash), "Vow/insufficient-debt");
        require(CDPEngine.dai(address(this)) == 0, "Vow/surplus-not-zero");
        Ash = add(Ash, sump);
        id = flopper.kick(address(this), dump, sump);
    }
    // Surplus auction
    function buyCollateral() external emitLog returns (uint id) {
        require(CDPEngine.dai(address(this)) >= add(add(CDPEngine.sin(address(this)), bump), hump), "Vow/insufficient-surplus");
        require(sub(sub(CDPEngine.sin(address(this)), Sin), Ash) == 0, "Vow/debt-not-zero");
        id = flapper.kick(bump, 0);
    }

    function cage() external emitLog onlyOwners {
        require(DSRisActive, "Vow/not-DSRisActive");
        DSRisActive = false;
        Sin = 0;
        Ash = 0;
        flapper.cage(CDPEngine.dai(address(flapper)));
        flopper.cage();
        CDPEngine.heal(min(CDPEngine.dai(address(this)), CDPEngine.sin(address(this))));
    }
}
