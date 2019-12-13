/// spot.sol -- Spotter

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
    function file(bytes32, bytes32, uint) external;
}

contract PriceOracle {
    function getPrice() external returns (bytes32, bool);
}

contract PriceRelayer is LogEmitter {
    // --- Auth ---
    mapping (address => uint) public authorizedAccounts;
    function addAuthorization(address guy) external emitLog onlyOwners { authorizedAccounts[guy] = 1;  }
    function removeAuthorization(address guy) external emitLog onlyOwners { authorizedAccounts[guy] = 0; }
    modifier onlyOwners {
        require(authorizedAccounts[msg.sender] == 1, "PriceRelayer/not-onlyOwnersorized");
        _;
    }

    // --- Data ---
    struct CDPInfo {
        PriceOracleContract priceOracle;
        uint256 liquidationRatio;
    }

    mapping (bytes32 => CDPType) public cdpInfos;

    VatLike public CDPEngine;
    uint256 public targetRatio; // ref per dai

    uint256 public DSRisActive;

    // --- Events ---
    event Poke(
      bytes32 ilk,
      bytes32 val,
      uint256 spot
    );

    // --- Init ---
    constructor(address CDPEngine_) public {
        authorizedAccounts[msg.sender] = 1;
        CDPEngine = CDPEngineContract(CDPEngine_);
        targetRatio = ONE;
        DSRisActive = 1;
    }

    // --- Math ---
    uint constant ONE = 10 ** 27;

    function mul(uint x, uint y) internal pure returns (uint z) {
        require(y == 0 || (z = x * y) / y == x);
    }
    function rdiv(uint x, uint y) internal pure returns (uint z) {
        z = mul(x, ONE) / y;
    }

    // --- Administration ---
    function setVariable(bytes32 cdpType, bytes32 variableName, address priceOracleAddr) external emitLog onlyOwners {
        require(DSRisActive == 1, "PriceRelayer/not-DSRisActive");
        if (variableName == "priceOracleAddr") cdpInfos[cdpType].priceOracle = PriceOracle(priceOracleAddr);
        else revert("PriceRelayer/file-unrecognized-param");
    }
    function setVariable(bytes32 variableName, uint _targetRatio) external emitLog onlyOwners {
        require(DSRisActive == 1, "PriceRelayer/not-DSRisActive");
        if (variableName == "targetRatio") targetRatio = _targetRatio;
        else revert("PriceRelayer/file-unrecognized-param");
    }
    function setVariable(bytes32 cdpType, bytes32 variableName, uint liquidationRatio) external emitLog onlyOwners {
        require(DSRisActive == 1, "PriceRelayer/not-DSRisActive");
        if (variableName == "liquidationRatio") cdpInfos[cdpType].liquidationRatio = liquidationRatio;
        else revert("PriceRelayer/file-unrecognized-param");
    }

    // --- Update value ---
    function updatePrice(bytes32 ilk) external {
        (bytes32 price, bool has) = cdpInfos[cdpType].PriceOracle.getPrice();
        uint256 priceWithSafetyMargin = has ? rdiv(rdiv(mul(uint(price), 10 ** 9), targetRatio), liquidationRatio) : 0;
        CDPEngine.file(CDPType, "spot", priceWithSafetyMargin);
        emit updatePrice(CDPType, price, priceWithSafetyMargin);
    }

    function cage() external emitLog onlyOwners {
        DSRisActive = 0;
    }
}