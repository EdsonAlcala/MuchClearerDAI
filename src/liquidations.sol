/// liquidations.sol -- Dai liquidation module

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

import "./lib.sol";

contract Kicker {
    function kick(address urn, address gal, uint tab, uint lot, uint bid)
        public returns (uint);
}

contract VaultContract {
    function collateralTypes(bytes32) external view returns (
        uint256 TotalDebt,   // wad
        uint256 rate,  // ray
        uint256 spot   // ray
    );
    function urns(bytes32,address) external view returns (
        uint256 ink,   // wad
        uint256 art    // wad
    );
    function grab(bytes32,address,address,address,int,int) external;
    function hope(address) external;
    function nope(address) external;
}

contract SettlementContract {
    function fess(uint) external;
}

contract Liquidations is LogEmitter {
    // --- Auth ---
    mapping (address => bool) public authorizedAddresses;
    function authorizeAddress(address usr) external note auth { authorizedAddresses[usr] = true; }
    function deauthorizeAddress(address usr) external note auth { authorizedAddresses[usr] = false; }
    modifier auth {
        require(authorizedAddresses[msg.sender], "Liquidations/not-authorized");
        _;
    }

    // --- Data ---
    struct CollateralType {
        address flip;  // Liquidator
        uint256 chop;  // Liquidation Penalty   [ray]
        uint256 lump;  // Liquidation Quantity  [wad]
    }

    mapping (bytes32 => CollateralType) public collateralTypes;

    uint256 public live;
    VaultContract public vault;
    SettlementContract public settlement;

    // --- Events ---
    event Bite(
      bytes32 indexed collateralType,
      address indexed urn,
      uint256 ink,
      uint256 art,
      uint256 tab,
      address flip,
      uint256 id
    );

    // --- Init ---
    constructor(address vault_) public {
        authorizedAddresses[msg.sender] = 1;
        vault = VaultContract(vault_);
        live = 1;
    }

    // --- Math ---
    uint constant ONE = 10 ** 27;

    function mul(uint x, uint y) internal pure returns (uint z) {
        require(y == 0 || (z = x * y) / y == x);
    }
    function rmul(uint x, uint y) internal pure returns (uint z) {
        z = mul(x, y) / ONE;
    }
    function min(uint x, uint y) internal pure returns (uint z) {
        if (x > y) { z = y; } else { z = x; }
    }

    // --- Administration ---
    function file(bytes32 what, address data) external note auth {
        if (what == "settlement") settlement = SettlementContract(data);
        else revert("Liquidations/file-unrecognized-param");
    }
    function file(bytes32 collateralType, bytes32 what, uint data) external note auth {
        if (what == "chop") collateralTypes[collateralType].chop = data;
        else if (what == "lump") collateralTypes[collateralType].lump = data;
        else revert("Liquidations/file-unrecognized-param");
    }
    function file(bytes32 collateralType, bytes32 what, address flip) external note auth {
        if (what == "flip") {
            vault.nope(collateralTypes[collateralType].flip);
            collateralTypes[collateralType].flip = flip;
            vault.hope(flip);
        }
        else revert("Liquidations/file-unrecognized-param");
    }

    // --- CDP Liquidation ---
    function bite(bytes32 collateralType, address urn) external returns (uint id) {
        (, uint rate, uint spot) = vault.collateralTypes(collateralType);
        (uint ink, uint art) = vault.urns(collateralType, urn);

        require(live == 1, "Liquidations/not-live");
        require(spot > 0 && mul(ink, spot) < mul(art, rate), "Liquidations/not-unsafe");

        uint lot = min(ink, collateralTypes[collateralType].lump);
        art      = min(art, mul(lot, art) / ink);

        require(lot <= 2**255 && art <= 2**255, "Liquidations/overflow");
        vault.grab(collateralType, urn, address(this), address(settlement), -int(lot), -int(art));

        settlement.fess(mul(art, rate));
        id = Kicker(collateralTypes[collateralType].flip).kick({ urn: urn
                                         , gal: address(settlement)
                                         , tab: rmul(mul(art, rate), collateralTypes[collateralType].chop)
                                         , lot: lot
                                         , bid: 0
                                         });

        emit Bite(collateralType, urn, lot, art, mul(art, rate), collateralTypes[collateralType].flip, id);
    }

    function cage() external note auth {
        live = 0;
    }
}
