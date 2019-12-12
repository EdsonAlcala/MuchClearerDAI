/// cat.sol -- Dai liquidation module

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

contract Kicker {
    function kick(address urn, address daiIncomeReceiver, uint tab, uint tokensForSale, uint bid)
        public returns (uint);
}

contract CDPEngineContract {
    function collateralTypes(bytes32) external view returns (
        uint256 debtAmount,   // amount
        uint256 accumulatedRates ,  // ray
        uint256 spot   // ray
    );
    function urns(bytes32,address) external view returns (
        uint256 ink,   // amount
        uint256 art    // amount
    );
    function grab(bytes32,address,address,address,int,int) external;
    function hope(address) external;
    function nope(address) external;
}

contract VowLike {
    function fess(uint) external;
}

contract Cat is LogEmitter, Permissioned {

    // --- Data ---
    struct CollateralType {
        address liquidator;  // Liquidator
        uint256 liquidatorPenalty;  // Liquidation Penalty   [ray]
        uint256 liquidatorAmount;  // Liquidation Quantity  [amount]
    }

    mapping (bytes32 => CollateralType) public collateralTypes;

    bool public DSRisActive;
    CDPEngineContract public CDPEngine;
    VowLike public debtEngine;

    // --- Events ---
    event CDPLiquidationEvent(
      bytes32 indexed collateralType,
      address indexed urn,
      uint256 ink,
      uint256 art,
      uint256 tab,
      address liquidator,
      uint256 id
    );

    // --- Init ---
    constructor(address CDPEngine_) public {
        authorizedAccounts[msg.sender] = true;
        CDPEngine = CDPEngineContract(CDPEngine_);
        DSRisActive = true;
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
    function file(bytes32 what, address data) external emitLog onlyOwners {
        if (what == "debtEngine") debtEngine = VowLike(data);
        else revert("Cat/file-unrecognized-param");
    }
    function file(bytes32 collateralType, bytes32 what, uint data) external emitLog onlyOwners {
        if (what == "liquidatorPenalty") collateralTypes[collateralType].liquidatorPenalty = data;
        else if (what == "liquidatorAmount") collateralTypes[collateralType].liquidatorAmount = data;
        else revert("Cat/file-unrecognized-param");
    }
    function file(bytes32 collateralType, bytes32 what, address liquidator) external emitLog onlyOwners {
        if (what == "liquidator") {
            CDPEngine.nope(collateralTypes[collateralType].liquidator);
            collateralTypes[collateralType].liquidator = liquidator;
            CDPEngine.hope(liquidator);
        }
        else revert("Cat/file-unrecognized-param");
    }

    // --- CDP Liquidation ---
    function CDPLiquidation(bytes32 collateralType, address urn) external returns (uint id) {
        (, uint accumulatedRates , uint spot) = CDPEngine.collateralTypes(collateralType);
        (uint ink, uint art) = CDPEngine.urns(collateralType, urn);

        require(DSRisActive, "Cat/not-DSRisActive");
        require(spot > 0 && mul(ink, spot) < mul(art, accumulatedRates ), "Cat/not-unsafe");

        uint tokensForSale = min(ink, collateralTypes[collateralType].liquidatorAmount);
        art      = min(art, mul(tokensForSale, art) / ink);

        require(tokensForSale <= 2**255 && art <= 2**255, "Cat/overflow");
        CDPEngine.grab(collateralType, urn, address(this), address(debtEngine), -int(tokensForSale), -int(art));

        debtEngine.fess(mul(art, accumulatedRates ));
        id = Kicker(collateralTypes[collateralType].liquidator).kick({ urn: urn
                                         , daiIncomeReceiver: address(debtEngine)
                                         , tab: rmul(mul(art, accumulatedRates ), collateralTypes[collateralType].liquidatorPenalty)
                                         , tokensForSale: tokensForSale
                                         , bid: 0
                                         });

        emit CDPLiquidationEvent(collateralType, urn, tokensForSale, art, mul(art, accumulatedRates ), collateralTypes[collateralType].liquidator, id);
    }

    function cage() external emitLog onlyOwners {
        DSRisActive = false;
    }
}
