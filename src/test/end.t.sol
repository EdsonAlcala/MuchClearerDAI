// end.t.sol -- global settlement tests

// Copyright (C) 2018 Rain <rainbreak@riseup.net>
// Copyright (C) 2018 Lev Livnev <lev@liv.nev.org.uk>
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

import "ds-test/test.sol";
import "ds-token/token.sol";
import "ds-value/value.sol";

import {CDPEngineInstance}  from '../CDPEngine.sol';
import {Cat}  from '../cat.sol';
import {Vow}  from '../debtEngine.sol';
import {DaiSavingsRateContract}  from '../daiSavingsRate.sol';
import {CollateralSellerContract} from '../liquidator.sol';
import {CollateralBuyerContract} from '../buyCollateral.sol';
import {Flopper} from '../flop.sol';
import {TokenAdapter} from '../enableDSR.sol';
import {GlobalSettlement}  from '../globalSettlement.sol';
import {Spotter} from '../spot.sol';

contract Hevm {
    function warp(uint256) public;
}

contract Usr {
    CDPEngineInstance public CDPEngine;
    GlobalSettlement public end;

    constructor(CDPEngineInstance CDPEngine_, GlobalSettlement end_) public {
        CDPEngine  = CDPEngine_;
        end  = end_;
    }
    function frob(bytes32 collateralType, address u, address v, address w, int dink, int dart) public {
        CDPEngine.frob(collateralType, u, v, w, dink, dart);
    }
    function flux(bytes32 collateralType, address src, address dst, uint256 amount) public {
        CDPEngine.flux(collateralType, src, dst, amount);
    }
    function move(address src, address dst, uint256 rad) public {
        CDPEngine.move(src, dst, rad);
    }
    function hope(address usr) public {
        CDPEngine.hope(usr);
    }
    function disableDSR(TokenAdapter gemA, address usr, uint amount) public {
        gemA.disableDSR(usr, amount);
    }
    function free(bytes32 collateralType) public {
        end.free(collateralType);
    }
    function pack(uint256 rad) public {
        end.pack(rad);
    }
    function cash(bytes32 collateralType, uint amount) public {
        end.cash(collateralType, amount);
    }
}

contract EndTest is DSTest {
    Hevm hevm;

    CDPEngineInstance   CDPEngine;
    GlobalSettlement   end;
    Vow   debtEngine;
    DaiSavingsRateContract   pot;
    Cat   cat;

    Spotter spot;

    struct CollateralType {
        DSValue pip;
        DSToken tokenCollateral;
        TokenAdapter gemA;
        CollateralSellerContract liquidator;
    }

    mapping (bytes32 => CollateralType) collateralTypes;

    CollateralBuyerContract buyCollateral;
    Flopper flop;

    uint constant WAD = 10 ** 18;
    uint constant RAY = 10 ** 27;

    function ray(uint amount) internal pure returns (uint) {
        return amount * 10 ** 9;
    }
    function rad(uint amount) internal pure returns (uint) {
        return amount * RAY;
    }
    function rmul(uint x, uint y) internal pure returns (uint z) {
        z = x * y;
        require(y == 0 || z / y == x);
        z = z / RAY;
    }
    function min(uint x, uint y) internal pure returns (uint z) {
        (x >= y) ? z = y : z = x;
    }
    function dai(address urn) internal view returns (uint) {
        return CDPEngine.dai(urn) / RAY;
    }
    function tokenCollateral(bytes32 collateralType, address urn) internal view returns (uint) {
        return CDPEngine.tokenCollateral(collateralType, urn);
    }
    function ink(bytes32 collateralType, address urn) internal view returns (uint) {
        (uint ink_, uint art_) = CDPEngine.urns(collateralType, urn); art_;
        return ink_;
    }
    function art(bytes32 collateralType, address urn) internal view returns (uint) {
        (uint ink_, uint art_) = CDPEngine.urns(collateralType, urn); ink_;
        return art_;
    }
    function debtAmount(bytes32 collateralType) internal view returns (uint) {
        (uint Art_, uint rate_, uint spot_, uint line_, uint dust_) = CDPEngine.collateralTypes(collateralType);
        rate_; spot_; line_; dust_;
        return Art_;
    }
    function balanceOf(bytes32 collateralType, address usr) internal view returns (uint) {
        return collateralTypes[collateralType].tokenCollateral.balanceOf(usr);
    }

    function try_pot_file(bytes32 what, uint data) public returns(bool ok) {
        string memory sig = "file(bytes32, uint)";
        (ok,) = address(pot).call(abi.encodeWithSignature(sig, what, data));
    }

    function init_collateral(bytes32 name) internal returns (CollateralType memory) {
        DSToken coin = new DSToken(name);
        coin.mint(20 ether);

        DSValue pip = new DSValue();
        spot.file(name, "pip", address(pip));
        spot.file(name, "mat", ray(1.5 ether));
        // initial collateral price of 5
        pip.poke(bytes32(5 * WAD));

        CDPEngine.init(name);
        TokenAdapter gemA = new TokenAdapter(address(CDPEngine), name, address(coin));

        // 1 coin = 6 dai and liquidation ratio is 200%
        CDPEngine.file(name, "spot",    ray(3 ether));
        CDPEngine.file(name, "line", rad(1000 ether));

        coin.approve(address(gemA));
        coin.approve(address(CDPEngine));

        CDPEngine.addAuthorization(address(gemA));

        CollateralSellerContract liquidator = new CollateralSellerContract(address(CDPEngine), name);
        CDPEngine.hope(address(liquidator));
        liquidator.addAuthorization(address(end));
        liquidator.addAuthorization(address(cat));
        cat.file(name, "liquidator", address(liquidator));
        cat.file(name, "liquidatorPenalty", ray(1 ether));
        cat.file(name, "liquidatorAmount", rad(15 ether));

        collateralTypes[name].pip = pip;
        collateralTypes[name].tokenCollateral = coin;
        collateralTypes[name].gemA = gemA;
        collateralTypes[name].liquidator = liquidator;

        return collateralTypes[name];
    }

    function setUp() public {
        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        hevm.warp(604411200);

        CDPEngine = new CDPEngineInstance();
        DSToken gov = new DSToken('GOV');

        buyCollateral = new CollateralBuyerContract(address(CDPEngine), address(gov));
        flop = new Flopper(address(CDPEngine), address(gov));
        gov.setOwner(address(flop));

        debtEngine = new Vow(address(CDPEngine), address(buyCollateral), address(flop));

        pot = new DaiSavingsRateContract(address(CDPEngine));
        CDPEngine.addAuthorization(address(pot));
        pot.file("debtEngine", address(debtEngine));

        cat = new Cat(address(CDPEngine));
        cat.file("debtEngine", address(debtEngine));
        CDPEngine.addAuthorization(address(cat));
        debtEngine.addAuthorization(address(cat));

        spot = new Spotter(address(CDPEngine));
        CDPEngine.file("Line",         rad(1000 ether));
        CDPEngine.addAuthorization(address(spot));

        end = new GlobalSettlement();
        end.file("CDPEngine", address(CDPEngine));
        end.file("cat", address(cat));
        end.file("debtEngine", address(debtEngine));
        end.file("pot", address(pot));
        end.file("spot", address(spot));
        end.file("wait", 1 hours);
        CDPEngine.addAuthorization(address(end));
        debtEngine.addAuthorization(address(end));
        spot.addAuthorization(address(end));
        pot.addAuthorization(address(end));
        cat.addAuthorization(address(end));
        buyCollateral.addAuthorization(address(debtEngine));
        flop.addAuthorization(address(debtEngine));
    }

    function test_cage_basic() public {
        assertEq(end.DSRisActive(), 1);
        assertEq(CDPEngine.DSRisActive(), 1);
        assertEq(cat.DSRisActive(), 1);
        assertEq(debtEngine.DSRisActive(), 1);
        assertEq(pot.DSRisActive(), 1);
        assertEq(debtEngine.flopper().DSRisActive(), 1);
        assertEq(debtEngine.flapper().DSRisActive(), 1);
        end.cage();
        assertEq(end.DSRisActive(), 0);
        assertEq(CDPEngine.DSRisActive(), 0);
        assertEq(cat.DSRisActive(), 0);
        assertEq(debtEngine.DSRisActive(), 0);
        assertEq(pot.DSRisActive(), 0);
        assertEq(debtEngine.flopper().DSRisActive(), 0);
        assertEq(debtEngine.flapper().DSRisActive(), 0);
    }

    function test_cage_pot_collectRate() public {
        assertEq(pot.DSRisActive(), 1);
        pot.collectRate();
        end.cage();

        assertEq(pot.DSRisActive(), 0);
        assertEq(pot.daiSavingsRate(), 10 ** 27);
        assertTrue(!try_pot_file("daiSavingsRate", 10 ** 27 + 1));
    }

    // -- Scenario where there is one over-collateralised CDP
    // -- and there is no Vow deficit or surplus
    function test_cage_collateralised() public {
        CollateralType memory gold = init_collateral("gold");

        Usr ali = new Usr(CDPEngine, end);

        // make a CDP:
        address urn1 = address(ali);
        gold.gemA.enableDSR(urn1, 10 ether);
        ali.frob("gold", urn1, urn1, urn1, 10 ether, 15 ether);
        // ali's urn has 0 tokenCollateral, 10 ink, 15 tab, 15 dai

        // global checks:
        assertEq(CDPEngine.debt(), rad(15 ether));
        assertEq(CDPEngine.vice(), 0);

        // collateral price is 5
        gold.pip.poke(bytes32(5 * WAD));
        end.cage();
        end.cage("gold");
        end.skim("gold", urn1);

        // local checks:
        assertEq(art("gold", urn1), 0);
        assertEq(ink("gold", urn1), 7 ether);
        assertEq(CDPEngine.sin(address(debtEngine)), rad(15 ether));

        // global checks:
        assertEq(CDPEngine.debt(), rad(15 ether));
        assertEq(CDPEngine.vice(), rad(15 ether));

        // CDP closing
        ali.free("gold");
        assertEq(ink("gold", urn1), 0);
        assertEq(tokenCollateral("gold", urn1), 7 ether);
        ali.disableDSR(gold.gemA, address(this), 7 ether);

        hevm.warp(now + 1 hours);
        end.thaw();
        end.flow("gold");
        assertTrue(end.fix("gold") != 0);

        // dai redemption
        ali.hope(address(end));
        ali.pack(15 ether);
        debtEngine.heal(rad(15 ether));

        // global checks:
        assertEq(CDPEngine.debt(), 0);
        assertEq(CDPEngine.vice(), 0);

        ali.cash("gold", 15 ether);

        // local checks:
        assertEq(dai(urn1), 0);
        assertEq(tokenCollateral("gold", urn1), 3 ether);
        ali.disableDSR(gold.gemA, address(this), 3 ether);

        assertEq(tokenCollateral("gold", address(end)), 0);
        assertEq(balanceOf("gold", address(gold.gemA)), 0);
    }

    // -- Scenario where there is one over-collateralised and one
    // -- under-collateralised CDP, and no Vow deficit or surplus
    function test_cage_undercollateralised() public {
        CollateralType memory gold = init_collateral("gold");

        Usr ali = new Usr(CDPEngine, end);
        Usr bob = new Usr(CDPEngine, end);

        // make a CDP:
        address urn1 = address(ali);
        gold.gemA.enableDSR(urn1, 10 ether);
        ali.frob("gold", urn1, urn1, urn1, 10 ether, 15 ether);
        // ali's urn has 0 tokenCollateral, 10 ink, 15 tab, 15 dai

        // make a second CDP:
        address urn2 = address(bob);
        gold.gemA.enableDSR(urn2, 1 ether);
        bob.frob("gold", urn2, urn2, urn2, 1 ether, 3 ether);
        // bob's urn has 0 tokenCollateral, 1 ink, 3 tab, 3 dai

        // global checks:
        assertEq(CDPEngine.debt(), rad(18 ether));
        assertEq(CDPEngine.vice(), 0);

        // collateral price is 2
        gold.pip.poke(bytes32(2 * WAD));
        end.cage();
        end.cage("gold");
        end.skim("gold", urn1);  // over-collateralised
        end.skim("gold", urn2);  // under-collateralised

        // local checks
        assertEq(art("gold", urn1), 0);
        assertEq(ink("gold", urn1), 2.5 ether);
        assertEq(art("gold", urn2), 0);
        assertEq(ink("gold", urn2), 0);
        assertEq(CDPEngine.sin(address(debtEngine)), rad(18 ether));

        // global checks
        assertEq(CDPEngine.debt(), rad(18 ether));
        assertEq(CDPEngine.vice(), rad(18 ether));

        // CDP closing
        ali.free("gold");
        assertEq(ink("gold", urn1), 0);
        assertEq(tokenCollateral("gold", urn1), 2.5 ether);
        ali.disableDSR(gold.gemA, address(this), 2.5 ether);

        hevm.warp(now + 1 hours);
        end.thaw();
        end.flow("gold");
        assertTrue(end.fix("gold") != 0);

        // first dai redemption
        ali.hope(address(end));
        ali.pack(15 ether);
        debtEngine.heal(rad(15 ether));

        // global checks:
        assertEq(CDPEngine.debt(), rad(3 ether));
        assertEq(CDPEngine.vice(), rad(3 ether));

        ali.cash("gold", 15 ether);

        // local checks:
        assertEq(dai(urn1), 0);
        uint256 fix = end.fix("gold");
        assertEq(tokenCollateral("gold", urn1), rmul(fix, 15 ether));
        ali.disableDSR(gold.gemA, address(this), rmul(fix, 15 ether));

        // second dai redemption
        bob.hope(address(end));
        bob.pack(3 ether);
        debtEngine.heal(rad(3 ether));

        // global checks:
        assertEq(CDPEngine.debt(), 0);
        assertEq(CDPEngine.vice(), 0);

        bob.cash("gold", 3 ether);

        // local checks:
        assertEq(dai(urn2), 0);
        assertEq(tokenCollateral("gold", urn2), rmul(fix, 3 ether));
        bob.disableDSR(gold.gemA, address(this), rmul(fix, 3 ether));

        // some dust remains in the GlobalSettlement because of rounding:
        assertEq(tokenCollateral("gold", address(end)), 1);
        assertEq(balanceOf("gold", address(gold.gemA)), 1);
    }

    // -- Scenario where there is one collateralised CDP
    // -- undergoing auction at the time of cage
    function test_cage_skip() public {
        CollateralType memory gold = init_collateral("gold");

        Usr ali = new Usr(CDPEngine, end);

        // make a CDP:
        address urn1 = address(ali);
        gold.gemA.enableDSR(urn1, 10 ether);
        ali.frob("gold", urn1, urn1, urn1, 10 ether, 15 ether);
        // this urn has 0 tokenCollateral, 10 ink, 15 tab, 15 dai

        CDPEngine.file("gold", "spot", ray(1 ether));     // now unsafe

        uint auction = cat.CDPLiquidation("gold", urn1);  // CDP liquidated
        assertEq(CDPEngine.vice(), rad(15 ether));    // now there is sin
        // get 1 dai from ali
        ali.move(address(ali), address(this), rad(1 ether));
        CDPEngine.hope(address(gold.liquidator));
        gold.liquidator.tend(auction, 10 ether, rad(1 ether)); // bid 1 dai
        assertEq(dai(urn1), 14 ether);

        // collateral price is 5
        gold.pip.poke(bytes32(5 * WAD));
        end.cage();
        end.cage("gold");

        end.skip("gold", auction);
        assertEq(dai(address(this)), 1 ether);       // bid refunded
        CDPEngine.move(address(this), urn1, rad(1 ether)); // return 1 dai to ali

        end.skim("gold", urn1);

        // local checks:
        assertEq(art("gold", urn1), 0);
        assertEq(ink("gold", urn1), 7 ether);
        assertEq(CDPEngine.sin(address(debtEngine)), rad(30 ether));

        // balance the debtEngine
        debtEngine.heal(min(CDPEngine.dai(address(debtEngine)), CDPEngine.sin(address(debtEngine))));
        // global checks:
        assertEq(CDPEngine.debt(), rad(15 ether));
        assertEq(CDPEngine.vice(), rad(15 ether));

        // CDP closing
        ali.free("gold");
        assertEq(ink("gold", urn1), 0);
        assertEq(tokenCollateral("gold", urn1), 7 ether);
        ali.disableDSR(gold.gemA, address(this), 7 ether);

        hevm.warp(now + 1 hours);
        end.thaw();
        end.flow("gold");
        assertTrue(end.fix("gold") != 0);

        // dai redemption
        ali.hope(address(end));
        ali.pack(15 ether);
        debtEngine.heal(rad(15 ether));

        // global checks:
        assertEq(CDPEngine.debt(), 0);
        assertEq(CDPEngine.vice(), 0);

        ali.cash("gold", 15 ether);

        // local checks:
        assertEq(dai(urn1), 0);
        assertEq(tokenCollateral("gold", urn1), 3 ether);
        ali.disableDSR(gold.gemA, address(this), 3 ether);

        assertEq(tokenCollateral("gold", address(end)), 0);
        assertEq(balanceOf("gold", address(gold.gemA)), 0);
    }

    // -- Scenario where there is one over-collateralised CDP
    // -- and there is a deficit in the Vow
    function test_cage_collateralised_deficit() public {
        CollateralType memory gold = init_collateral("gold");

        Usr ali = new Usr(CDPEngine, end);

        // make a CDP:
        address urn1 = address(ali);
        gold.gemA.enableDSR(urn1, 10 ether);
        ali.frob("gold", urn1, urn1, urn1, 10 ether, 15 ether);
        // ali's urn has 0 tokenCollateral, 10 ink, 15 tab, 15 dai
        // suck 1 dai and give to ali
        CDPEngine.suck(address(debtEngine), address(ali), rad(1 ether));

        // global checks:
        assertEq(CDPEngine.debt(), rad(16 ether));
        assertEq(CDPEngine.vice(), rad(1 ether));

        // collateral price is 5
        gold.pip.poke(bytes32(5 * WAD));
        end.cage();
        end.cage("gold");
        end.skim("gold", urn1);

        // local checks:
        assertEq(art("gold", urn1), 0);
        assertEq(ink("gold", urn1), 7 ether);
        assertEq(CDPEngine.sin(address(debtEngine)), rad(16 ether));

        // global checks:
        assertEq(CDPEngine.debt(), rad(16 ether));
        assertEq(CDPEngine.vice(), rad(16 ether));

        // CDP closing
        ali.free("gold");
        assertEq(ink("gold", urn1), 0);
        assertEq(tokenCollateral("gold", urn1), 7 ether);
        ali.disableDSR(gold.gemA, address(this), 7 ether);

        hevm.warp(now + 1 hours);
        end.thaw();
        end.flow("gold");
        assertTrue(end.fix("gold") != 0);

        // dai redemption
        ali.hope(address(end));
        ali.pack(16 ether);
        debtEngine.heal(rad(16 ether));

        // global checks:
        assertEq(CDPEngine.debt(), 0);
        assertEq(CDPEngine.vice(), 0);

        ali.cash("gold", 16 ether);

        // local checks:
        assertEq(dai(urn1), 0);
        assertEq(tokenCollateral("gold", urn1), 3 ether);
        ali.disableDSR(gold.gemA, address(this), 3 ether);

        assertEq(tokenCollateral("gold", address(end)), 0);
        assertEq(balanceOf("gold", address(gold.gemA)), 0);
    }

    // -- Scenario where there is one over-collateralised CDP
    // -- and one under-collateralised CDP and there is a
    // -- surplus in the Vow
    function test_cage_undercollateralised_surplus() public {
        CollateralType memory gold = init_collateral("gold");

        Usr ali = new Usr(CDPEngine, end);
        Usr bob = new Usr(CDPEngine, end);

        // make a CDP:
        address urn1 = address(ali);
        gold.gemA.enableDSR(urn1, 10 ether);
        ali.frob("gold", urn1, urn1, urn1, 10 ether, 15 ether);
        // ali's urn has 0 tokenCollateral, 10 ink, 15 tab, 15 dai
        // alive gives one dai to the debtEngine, creating surplus
        ali.move(address(ali), address(debtEngine), rad(1 ether));

        // make a second CDP:
        address urn2 = address(bob);
        gold.gemA.enableDSR(urn2, 1 ether);
        bob.frob("gold", urn2, urn2, urn2, 1 ether, 3 ether);
        // bob's urn has 0 tokenCollateral, 1 ink, 3 tab, 3 dai

        // global checks:
        assertEq(CDPEngine.debt(), rad(18 ether));
        assertEq(CDPEngine.vice(), 0);

        // collateral price is 2
        gold.pip.poke(bytes32(2 * WAD));
        end.cage();
        end.cage("gold");
        end.skim("gold", urn1);  // over-collateralised
        end.skim("gold", urn2);  // under-collateralised

        // local checks
        assertEq(art("gold", urn1), 0);
        assertEq(ink("gold", urn1), 2.5 ether);
        assertEq(art("gold", urn2), 0);
        assertEq(ink("gold", urn2), 0);
        assertEq(CDPEngine.sin(address(debtEngine)), rad(18 ether));

        // global checks
        assertEq(CDPEngine.debt(), rad(18 ether));
        assertEq(CDPEngine.vice(), rad(18 ether));

        // CDP closing
        ali.free("gold");
        assertEq(ink("gold", urn1), 0);
        assertEq(tokenCollateral("gold", urn1), 2.5 ether);
        ali.disableDSR(gold.gemA, address(this), 2.5 ether);

        hevm.warp(now + 1 hours);
        // balance the debtEngine
        debtEngine.heal(rad(1 ether));
        end.thaw();
        end.flow("gold");
        assertTrue(end.fix("gold") != 0);

        // first dai redemption
        ali.hope(address(end));
        ali.pack(14 ether);
        debtEngine.heal(rad(14 ether));

        // global checks:
        assertEq(CDPEngine.debt(), rad(3 ether));
        assertEq(CDPEngine.vice(), rad(3 ether));

        ali.cash("gold", 14 ether);

        // local checks:
        assertEq(dai(urn1), 0);
        uint256 fix = end.fix("gold");
        assertEq(tokenCollateral("gold", urn1), rmul(fix, 14 ether));
        ali.disableDSR(gold.gemA, address(this), rmul(fix, 14 ether));

        // second dai redemption
        bob.hope(address(end));
        bob.pack(3 ether);
        debtEngine.heal(rad(3 ether));

        // global checks:
        assertEq(CDPEngine.debt(), 0);
        assertEq(CDPEngine.vice(), 0);

        bob.cash("gold", 3 ether);

        // local checks:
        assertEq(dai(urn2), 0);
        assertEq(tokenCollateral("gold", urn2), rmul(fix, 3 ether));
        bob.disableDSR(gold.gemA, address(this), rmul(fix, 3 ether));

        // nothing left in the GlobalSettlement
        assertEq(tokenCollateral("gold", address(end)), 0);
        assertEq(balanceOf("gold", address(gold.gemA)), 0);
    }

    // -- Scenario where there is one over-collateralised and one
    // -- under-collateralised CDP of different collateral types
    // -- and no Vow deficit or surplus
    function test_cage_net_undercollateralised_multiple_ilks() public {
        CollateralType memory gold = init_collateral("gold");
        CollateralType memory coal = init_collateral("coal");

        Usr ali = new Usr(CDPEngine, end);
        Usr bob = new Usr(CDPEngine, end);

        // make a CDP:
        address urn1 = address(ali);
        gold.gemA.enableDSR(urn1, 10 ether);
        ali.frob("gold", urn1, urn1, urn1, 10 ether, 15 ether);
        // ali's urn has 0 tokenCollateral, 10 ink, 15 tab

        // make a second CDP:
        address urn2 = address(bob);
        coal.gemA.enableDSR(urn2, 1 ether);
        CDPEngine.file("coal", "spot", ray(5 ether));
        bob.frob("coal", urn2, urn2, urn2, 1 ether, 5 ether);
        // bob's urn has 0 tokenCollateral, 1 ink, 5 tab

        gold.pip.poke(bytes32(2 * WAD));
        // urn1 has 20 dai of ink and 15 dai of tab
        coal.pip.poke(bytes32(2 * WAD));
        // urn2 has 2 dai of ink and 5 dai of tab
        end.cage();
        end.cage("gold");
        end.cage("coal");
        end.skim("gold", urn1);  // over-collateralised
        end.skim("coal", urn2);  // under-collateralised

        hevm.warp(now + 1 hours);
        end.thaw();
        end.flow("gold");
        end.flow("coal");

        ali.hope(address(end));
        bob.hope(address(end));

        assertEq(CDPEngine.debt(),             rad(20 ether));
        assertEq(CDPEngine.vice(),             rad(20 ether));
        assertEq(CDPEngine.sin(address(debtEngine)),  rad(20 ether));

        assertEq(end.debtAmount("gold"), 15 ether);
        assertEq(end.debtAmount("coal"),  5 ether);

        assertEq(end.gap("gold"),  0.0 ether);
        assertEq(end.gap("coal"),  1.5 ether);

        // there are 7.5 gold and 1 coal
        // the gold is worth 15 dai and the coal is worth 2 dai
        // the total collateral pool is worth 17 dai
        // the total outstanding debt is 20 dai
        // each dai should get (15/2)/20 gold and (2/2)/20 coal
        assertEq(end.fix("gold"), ray(0.375 ether));
        assertEq(end.fix("coal"), ray(0.050 ether));

        assertEq(tokenCollateral("gold", address(ali)), 0 ether);
        ali.pack(1 ether);
        ali.cash("gold", 1 ether);
        assertEq(tokenCollateral("gold", address(ali)), 0.375 ether);

        bob.pack(1 ether);
        bob.cash("coal", 1 ether);
        assertEq(tokenCollateral("coal", address(bob)), 0.05 ether);

        ali.disableDSR(gold.gemA, address(ali), 0.375 ether);
        bob.disableDSR(coal.gemA, address(bob), 0.05  ether);
        ali.pack(1 ether);
        ali.cash("gold", 1 ether);
        ali.cash("coal", 1 ether);
        assertEq(tokenCollateral("gold", address(ali)), 0.375 ether);
        assertEq(tokenCollateral("coal", address(ali)), 0.05 ether);

        ali.disableDSR(gold.gemA, address(ali), 0.375 ether);
        ali.disableDSR(coal.gemA, address(ali), 0.05  ether);

        ali.pack(1 ether);
        ali.cash("gold", 1 ether);
        assertEq(end.out("gold", address(ali)), 3 ether);
        assertEq(end.out("coal", address(ali)), 1 ether);
        ali.pack(1 ether);
        ali.cash("coal", 1 ether);
        assertEq(end.out("gold", address(ali)), 3 ether);
        assertEq(end.out("coal", address(ali)), 2 ether);
        assertEq(tokenCollateral("gold", address(ali)), 0.375 ether);
        assertEq(tokenCollateral("coal", address(ali)), 0.05 ether);
    }
}
