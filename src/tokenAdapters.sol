/// join.sol -- Basic token adapters

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

contract TokenContract {
    function decimals() public view returns (uint);
    function transfer(address,uint) external returns (bool);
    function transferFrom(address,address,uint) external returns (bool);
}

contract DSTokenLike {
    function mint(address,uint) external;
    function burn(address,uint) external;
}

contract VaultContract {
    function slip(bytes32,address,int) external;
    function move(address,address,uint) external;
}

/*
    Here we provide *adapters* to connect the Vault to arbitrary external
    token implementations, creating a bounded context for the Vault. The
    adapters here are provided as working examples:

      - `ERC20Adapter`: For well behaved ERC20 tokens, with simple transfer
                   semantics.

      - `ETHAdapter`: For native Ether.

      - `DAITokenAdapter`: For connecting internal Dai balances to an external
                   `DSToken` implementation.

    In practice, adapter implementations will be varied and specific to
    individual collateral types, accounting for different transfer
    semantics and token standards.

    Adapters need to implement two basic methods:

      - `join`: enter collateral into the system
      - `exit`: remove collateral from the system

*/

contract ERC20Adapter is LogEmitter {
    // --- Auth ---
    mapping (address => bool) public authorizedAddresses;
    function authorizeAddress(address usr) external note auth { authorizedAddresses[usr] = true; }
    function deauthorizeAddress(address usr) external note auth { authorizedAddresses[usr] = false; }
    modifier auth {
        require(authorizedAddresses[msg.sender], "ERC20Adapter/not-authorized");
        _;
    }

    VaultContract public vault;
    bytes32 public collateralType;
    TokenContract public tokenCollateral;
    uint    public dec;
    uint    public live;  // Access Flag

    constructor(address vault_, bytes32 collateralType_, address gem_) public {
        authorizedAddresses[msg.sender] = 1;
        live = 1;
        vault = VaultContract(vault_);
        collateralType = collateralType_;
        tokenCollateral = TokenContract(gem_);
        dec = tokenCollateral.decimals();
    }
    function cage() external note auth {
        live = 0;
    }
    function join(address usr, uint wad) external note {
        require(live == 1, "ERC20Adapter/not-live");
        require(int(wad) >= 0, "ERC20Adapter/overflow");
        vault.slip(collateralType, usr, int(wad));
        require(tokenCollateral.transferFrom(msg.sender, address(this), wad), "ERC20Adapter/failed-transfer");
    }
    function exit(address usr, uint wad) external note {
        require(wad <= 2 ** 255, "ERC20Adapter/overflow");
        vault.slip(collateralType, msg.sender, -int(wad));
        require(tokenCollateral.transfer(usr, wad), "ERC20Adapter/failed-transfer");
    }
}

contract ETHAdapter is LogEmitter {
    // --- Auth ---
    mapping (address => bool) public authorizedAddresses;
    function authorizeAddress(address usr) external note auth { authorizedAddresses[usr] = true; }
    function deauthorizeAddress(address usr) external note auth { authorizedAddresses[usr] = false; }
    modifier auth {
        require(authorizedAddresses[msg.sender], "ETHAdapter/not-authorized");
        _;
    }

    VaultContract public vault;
    bytes32 public collateralType;
    uint    public live;  // Access Flag

    constructor(address vault_, bytes32 collateralType_) public {
        authorizedAddresses[msg.sender] = 1;
        live = 1;
        vault = VaultContract(vault_);
        collateralType = collateralType_;
    }
    function cage() external note auth {
        live = 0;
    }
    function join(address usr) external payable note {
        require(live == 1, "ETHAdapter/not-live");
        require(int(msg.value) >= 0, "ETHAdapter/overflow");
        vault.slip(collateralType, usr, int(msg.value));
    }
    function exit(address payable usr, uint wad) external note {
        require(int(wad) >= 0, "ETHAdapter/overflow");
        vault.slip(collateralType, msg.sender, -int(wad));
        usr.transfer(wad);
    }
}

contract DAITokenAdapter is LogEmitter {
    // --- Auth ---
    mapping (address => bool) public authorizedAddresses;
    function authorizeAddress(address usr) external note auth { authorizedAddresses[usr] = true; }
    function deauthorizeAddress(address usr) external note auth { authorizedAddresses[usr] = false; }
    modifier auth {
        require(authorizedAddresses[msg.sender], "DAITokenAdapter/not-authorized");
        _;
    }

    VaultContract public vault;
    DSTokenLike public dai;
    uint    public live;  // Access Flag

    constructor(address vault_, address dai_) public {
        authorizedAddresses[msg.sender] = 1;
        live = 1;
        vault = VaultContract(vault_);
        dai = DSTokenLike(dai_);
    }
    function cage() external note auth {
        live = 0;
    }
    uint constant ONE = 10 ** 27;
    function mul(uint x, uint y) internal pure returns (uint z) {
        require(y == 0 || (z = x * y) / y == x);
    }
    function join(address usr, uint wad) external note {
        vault.move(address(this), usr, mul(ONE, wad));
        dai.burn(msg.sender, wad);
    }
    function exit(address usr, uint wad) external note {
        require(live == 1, "DAITokenAdapter/not-live");
        vault.move(msg.sender, address(this), mul(ONE, wad));
        dai.mint(usr, wad);
    }
}
