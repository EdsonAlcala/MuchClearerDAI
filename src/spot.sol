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

contract VatLike {
    function file(bytes32, bytes32, uint) external;
}

contract PipLike {
    function peek() external returns (bytes32, bool);
}

contract Spotter is LogEmitter {
    // --- Auth ---
    mapping (address => uint) public authorizedAccounts;
    function addAuthorization(address guy) external emitLog onlyOwners { authorizedAccounts[guy] = 1;  }
    function removeAuthorization(address guy) external emitLog onlyOwners { authorizedAccounts[guy] = 0; }
    modifier onlyOwners {
        require(authorizedAccounts[msg.sender] == 1, "Spotter/not-onlyOwnersorized");
        _;
    }

    // --- Data ---
    struct Ilk {
        PipLike pip;
        uint256 mat;
    }

    mapping (bytes32 => Ilk) public ilks;

    VatLike public CDPEngine;
    uint256 public par; // ref per dai

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
        CDPEngine = VatLike(CDPEngine_);
        par = ONE;
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
    function file(bytes32 ilk, bytes32 what, address pip_) external emitLog onlyOwners {
        require(DSRisActive == 1, "Spotter/not-DSRisActive");
        if (what == "pip") ilks[ilk].pip = PipLike(pip_);
        else revert("Spotter/file-unrecognized-param");
    }
    function file(bytes32 what, uint data) external emitLog onlyOwners {
        require(DSRisActive == 1, "Spotter/not-DSRisActive");
        if (what == "par") par = data;
        else revert("Spotter/file-unrecognized-param");
    }
    function file(bytes32 ilk, bytes32 what, uint data) external emitLog onlyOwners {
        require(DSRisActive == 1, "Spotter/not-DSRisActive");
        if (what == "mat") ilks[ilk].mat = data;
        else revert("Spotter/file-unrecognized-param");
    }

    // --- Update value ---
    function poke(bytes32 ilk) external {
        (bytes32 val, bool has) = ilks[ilk].pip.peek();
        uint256 spot = has ? rdiv(rdiv(mul(uint(val), 10 ** 9), par), ilks[ilk].mat) : 0;
        CDPEngine.file(ilk, "spot", spot);
        emit Poke(ilk, val, spot);
    }

    function cage() external emitLog onlyOwners {
        DSRisActive = 0;
    }
}
