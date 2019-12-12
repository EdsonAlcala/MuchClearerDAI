/// enableDSR.sol -- Basic token adapters

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

contract SimpleToken {
    function decimals() public view returns (uint);
    function transfer(address,uint) external returns (bool);
    function transferFrom(address,address,uint) external returns (bool);
}

contract DSTokenLike {
    function mint(address,uint) external;
    function burn(address,uint) external;
}

contract CDPEngineContract {
    function slip(bytes32,address,int) external;
    function move(address,address,uint) external;
}

/*
    Here we provide *adapters* to connect the CDPEngineInstance to arbitrary external
    token implementations, creating a bounded context for the CDPEngineInstance. The
    adapters here are provided as working examples:

      - `TokenAdapter`: For well behaved ERC20 tokens, with simple transfer
                   semantics.

      - `ETHAdapter`: For native Ether.

      - `DAItoTokenAdapter`: For connecting internal Dai balances to an external
                   `DSToken` implementation.

    In practice, adapter implementations will be varied and specific to
    individual collateral types, accounting for different transfer
    semantics and token standards.

    Adapters need to implement two basic methods:

      - `enableDSR`: enter collateral into the system
      - `disableDSR`: remove collateral from the system

*/

contract TokenAdapter is LogEmitter, Permissioned {

    CDPEngineContract public CDPEngine;
    bytes32 public collateralType;
    SimpleToken public tokenCollateral;
    uint    public dec;
    uint    public DSRisActive;  // Access Flag

    constructor(address CDPEngine_, bytes32 ilk_, address token_) public {
        authorizedAccounts[msg.sender] = true;
        DSRisActive = true;
        CDPEngine = CDPEngineContract(CDPEngine_);
        collateralType = ilk_;
        tokenCollateral = SimpleToken(token_);
        dec = tokenCollateral.decimals();
    }
    function cage() external emitLog onlyOwners {
        DSRisActive = false;
    }
    function enableDSR(address usr, uint amount) external emitLog {
        require(DSRisActive, "TokenAdapter/not-DSRisActive");
        require(int(amount) >= 0, "TokenAdapter/overflow");
        CDPEngine.slip(collateralType, usr, int(amount));
        require(tokenCollateral.transferFrom(msg.sender, address(this), amount), "TokenAdapter/failed-transfer");
    }
    function disableDSR(address usr, uint amount) external emitLog {
        require(amount <= 2 ** 255, "TokenAdapter/overflow");
        CDPEngine.slip(collateralType, msg.sender, -int(amount));
        require(tokenCollateral.transfer(usr, amount), "TokenAdapter/failed-transfer");
    }
}

contract ETHAdapter is LogEmitter, Permissioned {

    CDPEngineContract public CDPEngine;
    bytes32 public collateralType;
    uint    public DSRisActive;  // Access Flag

    constructor(address CDPEngine_, bytes32 ilk_) public {
        authorizedAccounts[msg.sender] = true;
        DSRisActive = true;
        CDPEngine = CDPEngineContract(CDPEngine_);
        collateralType = ilk_;
    }
    function cage() external emitLog onlyOwners {
        DSRisActive = false;
    }
    function enableDSR(address usr) external payable emitLog {
        require(DSRisActive, "ETHAdapter/not-DSRisActive");
        require(int(msg.value) >= 0, "ETHAdapter/overflow");
        CDPEngine.slip(collateralType, usr, int(msg.value));
    }
    function disableDSR(address payable usr, uint amount) external emitLog {
        require(int(amount) >= 0, "ETHAdapter/overflow");
        CDPEngine.slip(collateralType, msg.sender, -int(amount));
        usr.transfer(amount);
    }
}

contract DAItoTokenAdapter is LogEmitter, Permissioned {

    CDPEngineContract public CDPEngine;
    DSTokenLike public dai;
    uint    public DSRisActive;  // Access Flag

    constructor(address CDPEngine_, address dai_) public {
        authorizedAccounts[msg.sender] = true;
        DSRisActive = true;
        CDPEngine = CDPEngineContract(CDPEngine_);
        dai = DSTokenLike(dai_);
    }
    function cage() external emitLog onlyOwners {
        DSRisActive = false;
    }
    uint constant ONE = 10 ** 27;
    function mul(uint x, uint y) internal pure returns (uint z) {
        require(y == 0 || (z = x * y) / y == x);
    }
    function enableDSR(address usr, uint amount) external emitLog {
        CDPEngine.move(address(this), usr, mul(ONE, amount));
        dai.burn(msg.sender, amount);
    }
    function disableDSR(address usr, uint amount) external emitLog {
        require(DSRisActive, "DAItoTokenAdapter/not-DSRisActive");
        CDPEngine.move(msg.sender, address(this), mul(ONE, amount));
        dai.mint(usr, amount);
    }
}
