pragma solidity 0.5.12;

import "ds-test/test.sol";
import "ds-token/token.sol";

import {CDPEngineInstance} from '../CDPEngine.sol';
import {Cat} from '../cat.sol';
import {Vow} from '../debtEngine.sol';
import {StabilityFees} from '../stabilityFees.sol';
import {TokenAdapter, ETHAdapter, DAItoTokenAdapter} from '../enableDSR.sol';

import {CollateralSellerContract} from './liquidator.t.sol';
import {Flopper} from './flop.t.sol';
import {CollateralBuyerContract} from './buyCollateral.t.sol';


contract Hevm {
    function warp(uint256) public;
}

contract TestVat is CDPEngineInstance {
    uint256 constant ONE = 10 ** 27;
    function mint(address usr, uint amount) public {
        dai[usr] += amount * ONE;
        debt += amount * ONE;
    }
    function balanceOf(address usr) public view returns (uint) {
        return dai[usr] / ONE;
    }
}

contract TestVow is Vow {
    constructor(address CDPEngine, address flapper, address flopper)
        public Vow(CDPEngine, flapper, flopper) {}
    // Total deficit
    function Awe() public view returns (uint) {
        return CDPEngine.sin(address(this));
    }
    // Total surplus
    function Joy() public view returns (uint) {
        return CDPEngine.dai(address(this));
    }
    // Unqueued, pre-auction debt
    function Woe() public view returns (uint) {
        return sub(sub(Awe(), Sin), Ash);
    }
}

contract Usr {
    CDPEngineInstance public CDPEngine;
    constructor(CDPEngineInstance CDPEngine_) public {
        CDPEngine = CDPEngine_;
    }
    function try_call(address addr, bytes calldata data) external returns (bool) {
        bytes memory _data = data;
        assembly {
            let ok := call(gas, addr, 0, add(_data, 0x20), mload(_data), 0, 0)
            let free := mload(0x40)
            mstore(free, ok)
            mstore(0x40, add(free, 32))
            revert(free, 32)
        }
    }
    function can_frob(bytes32 collateralType, address u, address v, address w, int dink, int dart) public returns (bool) {
        string memory sig = "frob(bytes32,address,address,address,int256,int256)";
        bytes memory data = abi.encodeWithSignature(sig, collateralType, u, v, w, dink, dart);

        bytes memory can_call = abi.encodeWithSignature("try_call(address,bytes)", CDPEngine, data);
        (bool ok, bytes memory success) = address(this).call(can_call);

        ok = abi.decode(success, (bool));
        if (ok) return true;
    }
    function can_fork(bytes32 collateralType, address src, address dst, int dink, int dart) public returns (bool) {
        string memory sig = "fork(bytes32,address,address,int256,int256)";
        bytes memory data = abi.encodeWithSignature(sig, collateralType, src, dst, dink, dart);

        bytes memory can_call = abi.encodeWithSignature("try_call(address,bytes)", CDPEngine, data);
        (bool ok, bytes memory success) = address(this).call(can_call);

        ok = abi.decode(success, (bool));
        if (ok) return true;
    }
    function frob(bytes32 collateralType, address u, address v, address w, int dink, int dart) public {
        CDPEngine.frob(collateralType, u, v, w, dink, dart);
    }
    function fork(bytes32 collateralType, address src, address dst, int dink, int dart) public {
        CDPEngine.fork(collateralType, src, dst, dink, dart);
    }
    function hope(address usr) public {
        CDPEngine.hope(usr);
    }
}


contract FrobTest is DSTest {
    TestVat CDPEngine;
    DSToken gold;
    StabilityFees     stabilityFees;

    TokenAdapter gemA;
    address me;

    function try_frob(bytes32 collateralType, int ink, int art) public returns (bool ok) {
        string memory sig = "frob(bytes32,address,address,address,int256,int256)";
        address self = address(this);
        (ok,) = address(CDPEngine).call(abi.encodeWithSignature(sig, collateralType, self, self, self, ink, art));
    }

    function ray(uint amount) internal pure returns (uint) {
        return amount * 10 ** 9;
    }

    function setUp() public {
        CDPEngine = new TestVat();

        gold = new DSToken("GEM");
        gold.mint(1000 ether);

        CDPEngine.init("gold");
        gemA = new TokenAdapter(address(CDPEngine), "gold", address(gold));

        CDPEngine.file("gold", "spot",    ray(1 ether));
        CDPEngine.file("gold", "line", rad(1000 ether));
        CDPEngine.file("Line",         rad(1000 ether));
        stabilityFees = new StabilityFees(address(CDPEngine));
        stabilityFees.init("gold");
        CDPEngine.addAuthorization(address(stabilityFees));

        gold.approve(address(gemA));
        gold.approve(address(CDPEngine));

        CDPEngine.addAuthorization(address(CDPEngine));
        CDPEngine.addAuthorization(address(gemA));

        gemA.enableDSR(address(this), 1000 ether);

        me = address(this);
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

    function test_setup() public {
        assertEq(gold.balanceOf(address(gemA)), 1000 ether);
        assertEq(tokenCollateral("gold",    address(this)), 1000 ether);
    }
    function test_enableDSR() public {
        address urn = address(this);
        gold.mint(500 ether);
        assertEq(gold.balanceOf(address(this)),    500 ether);
        assertEq(gold.balanceOf(address(gemA)),   1000 ether);
        gemA.enableDSR(urn,                             500 ether);
        assertEq(gold.balanceOf(address(this)),      0 ether);
        assertEq(gold.balanceOf(address(gemA)),   1500 ether);
        gemA.disableDSR(urn,                             250 ether);
        assertEq(gold.balanceOf(address(this)),    250 ether);
        assertEq(gold.balanceOf(address(gemA)),   1250 ether);
    }
    function test_lock() public {
        assertEq(ink("gold", address(this)),    0 ether);
        assertEq(tokenCollateral("gold", address(this)), 1000 ether);
        CDPEngine.frob("gold", me, me, me, 6 ether, 0);
        assertEq(ink("gold", address(this)),   6 ether);
        assertEq(tokenCollateral("gold", address(this)), 994 ether);
        CDPEngine.frob("gold", me, me, me, -6 ether, 0);
        assertEq(ink("gold", address(this)),    0 ether);
        assertEq(tokenCollateral("gold", address(this)), 1000 ether);
    }
    function test_calm() public {
        // calm means that the debt ceiling is not exceeded
        // it's ok to increase debt as long as you remain calm
        CDPEngine.file("gold", 'line', rad(10 ether));
        assertTrue( try_frob("gold", 10 ether, 9 ether));
        // only if under debt ceiling
        assertTrue(!try_frob("gold",  0 ether, 2 ether));
    }
    function test_cool() public {
        // cool means that the debt has decreased
        // it's ok to be over the debt ceiling as long as you're cool
        CDPEngine.file("gold", 'line', rad(10 ether));
        assertTrue(try_frob("gold", 10 ether,  8 ether));
        CDPEngine.file("gold", 'line', rad(5 ether));
        // can decrease debt when over ceiling
        assertTrue(try_frob("gold",  0 ether, -1 ether));
    }
    function test_safe() public {
        // safe means that the cdp is not risky
        // you can't frob a cdp into unsafe
        CDPEngine.frob("gold", me, me, me, 10 ether, 5 ether);                // safe draw
        assertTrue(!try_frob("gold", 0 ether, 6 ether));  // unsafe draw
    }
    function test_nice() public {
        // nice means that the collateral has increased or the debt has
        // decreased. remaining unsafe is ok as long as you're nice

        CDPEngine.frob("gold", me, me, me, 10 ether, 10 ether);
        CDPEngine.file("gold", 'spot', ray(0.5 ether));  // now unsafe

        // debt can't increase if unsafe
        assertTrue(!try_frob("gold",  0 ether,  1 ether));
        // debt can decrease
        assertTrue( try_frob("gold",  0 ether, -1 ether));
        // ink can't decrease
        assertTrue(!try_frob("gold", -1 ether,  0 ether));
        // ink can increase
        assertTrue( try_frob("gold",  1 ether,  0 ether));

        // cdp is still unsafe
        // ink can't decrease, even if debt decreases more
        assertTrue(!this.try_frob("gold", -2 ether, -4 ether));
        // debt can't increase, even if ink increases more
        assertTrue(!this.try_frob("gold",  5 ether,  1 ether));

        // ink can decrease if end state is safe
        assertTrue( this.try_frob("gold", -1 ether, -4 ether));
        CDPEngine.file("gold", 'spot', ray(0.4 ether));  // now unsafe
        // debt can increase if end state is safe
        assertTrue( this.try_frob("gold",  5 ether, 1 ether));
    }

    function rad(uint amount) internal pure returns (uint) {
        return amount * 10 ** 27;
    }
    function test_alt_callers() public {
        Usr ali = new Usr(CDPEngine);
        Usr bob = new Usr(CDPEngine);
        Usr che = new Usr(CDPEngine);

        address a = address(ali);
        address b = address(bob);
        address c = address(che);

        CDPEngine.slip("gold", a, int(rad(20 ether)));
        CDPEngine.slip("gold", b, int(rad(20 ether)));
        CDPEngine.slip("gold", c, int(rad(20 ether)));

        ali.frob("gold", a, a, a, 10 ether, 5 ether);

        // anyone can lock
        assertTrue( ali.can_frob("gold", a, a, a,  1 ether,  0 ether));
        assertTrue( bob.can_frob("gold", a, b, b,  1 ether,  0 ether));
        assertTrue( che.can_frob("gold", a, c, c,  1 ether,  0 ether));
        // but only with their own gems
        assertTrue(!ali.can_frob("gold", a, b, a,  1 ether,  0 ether));
        assertTrue(!bob.can_frob("gold", a, c, b,  1 ether,  0 ether));
        assertTrue(!che.can_frob("gold", a, a, c,  1 ether,  0 ether));

        // only the lad can free
        assertTrue( ali.can_frob("gold", a, a, a, -1 ether,  0 ether));
        assertTrue(!bob.can_frob("gold", a, b, b, -1 ether,  0 ether));
        assertTrue(!che.can_frob("gold", a, c, c, -1 ether,  0 ether));
        // the lad can free to anywhere
        assertTrue( ali.can_frob("gold", a, b, a, -1 ether,  0 ether));
        assertTrue( ali.can_frob("gold", a, c, a, -1 ether,  0 ether));

        // only the lad can draw
        assertTrue( ali.can_frob("gold", a, a, a,  0 ether,  1 ether));
        assertTrue(!bob.can_frob("gold", a, b, b,  0 ether,  1 ether));
        assertTrue(!che.can_frob("gold", a, c, c,  0 ether,  1 ether));
        // the lad can draw to anywhere
        assertTrue( ali.can_frob("gold", a, a, b,  0 ether,  1 ether));
        assertTrue( ali.can_frob("gold", a, a, c,  0 ether,  1 ether));

        CDPEngine.mint(address(bob), 1 ether);
        CDPEngine.mint(address(che), 1 ether);

        // anyone can wipe
        assertTrue( ali.can_frob("gold", a, a, a,  0 ether, -1 ether));
        assertTrue( bob.can_frob("gold", a, b, b,  0 ether, -1 ether));
        assertTrue( che.can_frob("gold", a, c, c,  0 ether, -1 ether));
        // but only with their own dai
        assertTrue(!ali.can_frob("gold", a, a, b,  0 ether, -1 ether));
        assertTrue(!bob.can_frob("gold", a, b, c,  0 ether, -1 ether));
        assertTrue(!che.can_frob("gold", a, c, a,  0 ether, -1 ether));
    }

    function test_hope() public {
        Usr ali = new Usr(CDPEngine);
        Usr bob = new Usr(CDPEngine);
        Usr che = new Usr(CDPEngine);

        address a = address(ali);
        address b = address(bob);
        address c = address(che);

        CDPEngine.slip("gold", a, int(rad(20 ether)));
        CDPEngine.slip("gold", b, int(rad(20 ether)));
        CDPEngine.slip("gold", c, int(rad(20 ether)));

        ali.frob("gold", a, a, a, 10 ether, 5 ether);

        // only owner can do risky actions
        assertTrue( ali.can_frob("gold", a, a, a,  0 ether,  1 ether));
        assertTrue(!bob.can_frob("gold", a, b, b,  0 ether,  1 ether));
        assertTrue(!che.can_frob("gold", a, c, c,  0 ether,  1 ether));

        ali.hope(address(bob));

        // unless they hope another user
        assertTrue( ali.can_frob("gold", a, a, a,  0 ether,  1 ether));
        assertTrue( bob.can_frob("gold", a, b, b,  0 ether,  1 ether));
        assertTrue(!che.can_frob("gold", a, c, c,  0 ether,  1 ether));
    }

    function test_dust() public {
        assertTrue( try_frob("gold", 9 ether,  1 ether));
        CDPEngine.file("gold", "dust", rad(5 ether));
        assertTrue(!try_frob("gold", 5 ether,  2 ether));
        assertTrue( try_frob("gold", 0 ether,  5 ether));
        assertTrue(!try_frob("gold", 0 ether, -5 ether));
        assertTrue( try_frob("gold", 0 ether, -6 ether));
    }
}

contract JoinTest is DSTest {
    TestVat CDPEngine;
    DSToken tokenCollateral;
    TokenAdapter gemA;
    ETHAdapter ethA;
    DAItoTokenAdapter daiA;
    DSToken dai;
    address me;

    function setUp() public {
        CDPEngine = new TestVat();
        CDPEngine.init("eth");

        tokenCollateral  = new DSToken("Gem");
        gemA = new TokenAdapter(address(CDPEngine), "tokenCollateral", address(tokenCollateral));
        CDPEngine.addAuthorization(address(gemA));

        ethA = new ETHAdapter(address(CDPEngine), "eth");
        CDPEngine.addAuthorization(address(ethA));

        dai  = new DSToken("Dai");
        daiA = new DAItoTokenAdapter(address(CDPEngine), address(dai));
        CDPEngine.addAuthorization(address(daiA));
        dai.setOwner(address(daiA));

        me = address(this);
    }
    function try_cage(address a) public payable returns (bool ok) {
        string memory sig = "cage()";
        (ok,) = a.call(abi.encodeWithSignature(sig));
    }
    function try_enableDSR_gem(address usr, uint amount) public returns (bool ok) {
        string memory sig = "enableDSR(address,uint256)";
        (ok,) = address(gemA).call(abi.encodeWithSignature(sig, usr, amount));
    }
    function try_enableDSR_eth(address usr) public payable returns (bool ok) {
        string memory sig = "enableDSR(address)";
        (ok,) = address(ethA).call.value(msg.value)(abi.encodeWithSignature(sig, usr));
    }
    function try_disableDSR_dai(address usr, uint amount) public returns (bool ok) {
        string memory sig = "disableDSR(address,uint256)";
        (ok,) = address(daiA).call(abi.encodeWithSignature(sig, usr, amount));
    }
    function () external payable {}
    function test_gem_enableDSR() public {
        tokenCollateral.mint(20 ether);
        tokenCollateral.approve(address(gemA), 20 ether);
        assertTrue( try_enableDSR_gem(address(this), 10 ether));
        assertEq(CDPEngine.tokenCollateral("tokenCollateral", me), 10 ether);
        assertTrue( try_cage(address(gemA)));
        assertTrue(!try_enableDSR_gem(address(this), 10 ether));
        assertEq(CDPEngine.tokenCollateral("tokenCollateral", me), 10 ether);
    }
    function test_eth_enableDSR() public {
        assertTrue( this.try_enableDSR_eth.value(10 ether)(address(this)));
        assertEq(CDPEngine.tokenCollateral("eth", me), 10 ether);
        assertTrue( try_cage(address(ethA)));
        assertTrue(!this.try_enableDSR_eth.value(10 ether)(address(this)));
        assertEq(CDPEngine.tokenCollateral("eth", me), 10 ether);
    }
    function test_eth_disableDSR() public {
        address payable urn = address(this);
        ethA.enableDSR.value(50 ether)(urn);
        ethA.disableDSR(urn, 10 ether);
        assertEq(CDPEngine.tokenCollateral("eth", me), 40 ether);
    }
    function rad(uint amount) internal pure returns (uint) {
        return amount * 10 ** 27;
    }
    function test_dai_disableDSR() public {
        address urn = address(this);
        CDPEngine.mint(address(this), 100 ether);
        CDPEngine.hope(address(daiA));
        assertTrue( try_disableDSR_dai(urn, 40 ether));
        assertEq(dai.balanceOf(address(this)), 40 ether);
        assertEq(CDPEngine.dai(me),              rad(60 ether));
        assertTrue( try_cage(address(daiA)));
        assertTrue(!try_disableDSR_dai(urn, 40 ether));
        assertEq(dai.balanceOf(address(this)), 40 ether);
        assertEq(CDPEngine.dai(me),              rad(60 ether));
    }
    function test_dai_disableDSR_enableDSR() public {
        address urn = address(this);
        CDPEngine.mint(address(this), 100 ether);
        CDPEngine.hope(address(daiA));
        daiA.disableDSR(urn, 60 ether);
        dai.approve(address(daiA), uint(-1));
        daiA.enableDSR(urn, 30 ether);
        assertEq(dai.balanceOf(address(this)),     30 ether);
        assertEq(CDPEngine.dai(me),                  rad(70 ether));
    }
    function test_fallback_reverts() public {
        (bool ok,) = address(ethA).call("invalid calldata");
        assertTrue(!ok);
    }
    function test_nonzero_fallback_reverts() public {
        (bool ok,) = address(ethA).call.value(10)("invalid calldata");
        assertTrue(!ok);
    }
    function test_cage_no_access() public {
        gemA.removeAuthorization(address(this));
        assertTrue(!try_cage(address(gemA)));
        ethA.removeAuthorization(address(this));
        assertTrue(!try_cage(address(ethA)));
        daiA.removeAuthorization(address(this));
        assertTrue(!try_cage(address(daiA)));
    }
}

contract FlipLike {
    struct Bid {
        uint256 bid;
        uint256 tokensForSale;
        address guy;  // high bidder
        uint48  tic;  // expiry time
        uint48  end;
        address urn;
        address daiIncomeReceiver;
        uint256 tab;
    }
    function bids(uint) public view returns (
        uint256 bid,
        uint256 tokensForSale,
        address guy,
        uint48  tic,
        uint48  end,
        address usr,
        address daiIncomeReceiver,
        uint256 tab
    );
}

contract BiteTest is DSTest {
    Hevm hevm;

    TestVat CDPEngine;
    TestVow debtEngine;
    Cat     cat;
    DSToken gold;
    StabilityFees     stabilityFees;

    TokenAdapter gemA;

    CollateralSellerContract liquidator;
    Flopper flop;
    CollateralBuyerContract buyCollateral;

    DSToken gov;

    address me;

    function try_frob(bytes32 collateralType, int ink, int art) public returns (bool ok) {
        string memory sig = "frob(bytes32,address,address,address,int256,int256)";
        address self = address(this);
        (ok,) = address(CDPEngine).call(abi.encodeWithSignature(sig, collateralType, self, self, self, ink, art));
    }

    function ray(uint amount) internal pure returns (uint) {
        return amount * 10 ** 9;
    }
    function rad(uint amount) internal pure returns (uint) {
        return amount * 10 ** 27;
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

    function setUp() public {
        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        hevm.warp(604411200);

        gov = new DSToken('GOV');
        gov.mint(100 ether);

        CDPEngine = new TestVat();
        CDPEngine = CDPEngine;

        buyCollateral = new CollateralBuyerContract(address(CDPEngine), address(gov));
        flop = new Flopper(address(CDPEngine), address(gov));

        debtEngine = new TestVow(address(CDPEngine), address(buyCollateral), address(flop));
        buyCollateral.addAuthorization(address(debtEngine));
        flop.addAuthorization(address(debtEngine));

        stabilityFees = new StabilityFees(address(CDPEngine));
        stabilityFees.init("gold");
        stabilityFees.file("debtEngine", address(debtEngine));
        CDPEngine.addAuthorization(address(stabilityFees));

        cat = new Cat(address(CDPEngine));
        cat.file("debtEngine", address(debtEngine));
        CDPEngine.addAuthorization(address(cat));
        debtEngine.addAuthorization(address(cat));

        gold = new DSToken("GEM");
        gold.mint(1000 ether);

        CDPEngine.init("gold");
        gemA = new TokenAdapter(address(CDPEngine), "gold", address(gold));
        CDPEngine.addAuthorization(address(gemA));
        gold.approve(address(gemA));
        gemA.enableDSR(address(this), 1000 ether);

        CDPEngine.file("gold", "spot", ray(1 ether));
        CDPEngine.file("gold", "line", rad(1000 ether));
        CDPEngine.file("Line",         rad(1000 ether));
        liquidator = new CollateralSellerContract(address(CDPEngine), "gold");
        liquidator.addAuthorization(address(cat));
        cat.file("gold", "liquidator", address(liquidator));
        cat.file("gold", "liquidatorPenalty", ray(1 ether));

        CDPEngine.addAuthorization(address(liquidator));
        CDPEngine.addAuthorization(address(buyCollateral));
        CDPEngine.addAuthorization(address(flop));

        CDPEngine.hope(address(liquidator));
        CDPEngine.hope(address(flop));
        gold.approve(address(CDPEngine));
        gov.approve(address(buyCollateral));

        me = address(this);
    }

    function test_bite_under_lump() public {
        CDPEngine.file("gold", 'spot', ray(2.5 ether));
        CDPEngine.frob("gold", me, me, me, 40 ether, 100 ether);
        // tag=4, mat=2
        CDPEngine.file("gold", 'spot', ray(2 ether));  // now unsafe

        cat.file("gold", "liquidatorAmount", 50 ether);
        cat.file("gold", "liquidatorPenalty", ray(1.1 ether));

        uint auction = cat.CDPLiquidation("gold", address(this));
        // the full CDP is liquidated
        assertEq(ink("gold", address(this)), 0);
        assertEq(art("gold", address(this)), 0);
        // all debt goes to the debtEngine
        assertEq(debtEngine.Awe(), rad(100 ether));
        // auction is for all collateral
        (, uint tokensForSale,,,,,, uint tab) = FlipLike(address(liquidator)).bids(auction);
        assertEq(tokensForSale,        40 ether);
        assertEq(tab,   rad(110 ether));
    }
    function test_bite_over_lump() public {
        CDPEngine.file("gold", 'spot', ray(2.5 ether));
        CDPEngine.frob("gold", me, me, me, 40 ether, 100 ether);
        // tag=4, mat=2
        CDPEngine.file("gold", 'spot', ray(2 ether));  // now unsafe

        cat.file("gold", "liquidatorPenalty", ray(1.1 ether));
        cat.file("gold", "liquidatorAmount", 30 ether);

        uint auction = cat.CDPLiquidation("gold", address(this));
        // the CDP is partially liquidated
        assertEq(ink("gold", address(this)), 10 ether);
        assertEq(art("gold", address(this)), 25 ether);
        // a fraction of the debt goes to the debtEngine
        assertEq(debtEngine.Awe(), rad(75 ether));
        // auction is for a fraction of the collateral
        (, uint tokensForSale,,,,,, uint tab) = FlipLike(address(liquidator)).bids(auction);
        assertEq(tokensForSale,       30 ether);
        assertEq(tab,   rad(82.5 ether));
    }

    function test_happy_bite() public {
        // spot = tag / (par . mat)
        // tag=5, mat=2
        CDPEngine.file("gold", 'spot', ray(2.5 ether));
        CDPEngine.frob("gold", me, me, me, 40 ether, 100 ether);

        // tag=4, mat=2
        CDPEngine.file("gold", 'spot', ray(2 ether));  // now unsafe

        assertEq(ink("gold", address(this)),  40 ether);
        assertEq(art("gold", address(this)), 100 ether);
        assertEq(debtEngine.Woe(), 0 ether);
        assertEq(tokenCollateral("gold", address(this)), 960 ether);

        cat.file("gold", "liquidatorAmount", 100 ether);  // => CDPLiquidation everything
        uint auction = cat.CDPLiquidation("gold", address(this));
        assertEq(ink("gold", address(this)), 0);
        assertEq(art("gold", address(this)), 0);
        assertEq(debtEngine.sin(now),   rad(100 ether));
        assertEq(tokenCollateral("gold", address(this)), 960 ether);

        assertEq(CDPEngine.balanceOf(address(debtEngine)),    0 ether);
        liquidator.tend(auction, 40 ether,   rad(1 ether));
        liquidator.tend(auction, 40 ether, rad(100 ether));

        assertEq(CDPEngine.balanceOf(address(this)),   0 ether);
        assertEq(tokenCollateral("gold", address(this)),   960 ether);
        CDPEngine.mint(address(this), 100 ether);  // magic up some dai for bidding
        liquidator.dent(auction, 38 ether,  rad(100 ether));
        assertEq(CDPEngine.balanceOf(address(this)), 100 ether);
        assertEq(tokenCollateral("gold", address(this)),   962 ether);
        assertEq(tokenCollateral("gold", address(this)),   962 ether);
        assertEq(debtEngine.sin(now),     rad(100 ether));

        hevm.warp(now + 4 hours);
        liquidator.deal(auction);
        assertEq(CDPEngine.balanceOf(address(debtEngine)),  100 ether);
    }

    function test_floppy_bite() public {
        CDPEngine.file("gold", 'spot', ray(2.5 ether));
        CDPEngine.frob("gold", me, me, me, 40 ether, 100 ether);
        CDPEngine.file("gold", 'spot', ray(2 ether));  // now unsafe

        cat.file("gold", "liquidatorAmount", 100 ether);  // => CDPLiquidation everything
        assertEq(debtEngine.sin(now), rad(  0 ether));
        cat.CDPLiquidation("gold", address(this));
        assertEq(debtEngine.sin(now), rad(100 ether));

        assertEq(debtEngine.Sin(), rad(100 ether));
        debtEngine.flog(now);
        assertEq(debtEngine.Sin(), rad(  0 ether));
        assertEq(debtEngine.Woe(), rad(100 ether));
        assertEq(debtEngine.Joy(), rad(  0 ether));
        assertEq(debtEngine.Ash(), rad(  0 ether));

        debtEngine.file("sump", rad(10 ether));
        debtEngine.file("dump", 2000 ether);
        uint f1 = debtEngine.flop();
        assertEq(debtEngine.Woe(),  rad(90 ether));
        assertEq(debtEngine.Joy(),  rad( 0 ether));
        assertEq(debtEngine.Ash(),  rad(10 ether));
        flop.dent(f1, 1000 ether, rad(10 ether));
        assertEq(debtEngine.Woe(),  rad(90 ether));
        assertEq(debtEngine.Joy(),  rad(10 ether));
        assertEq(debtEngine.Ash(),  rad(10 ether));

        assertEq(gov.balanceOf(address(this)),  100 ether);
        hevm.warp(now + 4 hours);
        gov.setOwner(address(flop));
        flop.deal(f1);
        assertEq(gov.balanceOf(address(this)), 1100 ether);
    }

    function test_flappy_bite() public {
        // get some surplus
        CDPEngine.mint(address(debtEngine), 100 ether);
        assertEq(CDPEngine.balanceOf(address(debtEngine)),  100 ether);
        assertEq(gov.balanceOf(address(this)), 100 ether);

        debtEngine.file("bump", rad(100 ether));
        assertEq(debtEngine.Awe(), 0 ether);
        uint id = debtEngine.buyCollateral();

        assertEq(CDPEngine.balanceOf(address(this)),   0 ether);
        assertEq(gov.balanceOf(address(this)), 100 ether);
        buyCollateral.tend(id, rad(100 ether), 10 ether);
        hevm.warp(now + 4 hours);
        gov.setOwner(address(buyCollateral));
        buyCollateral.deal(id);
        assertEq(CDPEngine.balanceOf(address(this)),   100 ether);
        assertEq(gov.balanceOf(address(this)),    90 ether);
    }
}

contract FoldTest is DSTest {
    CDPEngineInstance CDPEngine;

    function ray(uint amount) internal pure returns (uint) {
        return amount * 10 ** 9;
    }
    function rad(uint amount) internal pure returns (uint) {
        return amount * 10 ** 27;
    }
    function tab(bytes32 collateralType, address urn) internal view returns (uint) {
        (uint ink_, uint art_) = CDPEngine.urns(collateralType, urn); ink_;
        (uint Art_, uint accumulatedRates , uint spot, uint line, uint dust) = CDPEngine.collateralTypes(collateralType);
        Art_; spot; line; dust;
        return art_ * accumulatedRates ;
    }
    function jam(bytes32 collateralType, address urn) internal view returns (uint) {
        (uint ink_, uint art_) = CDPEngine.urns(collateralType, urn); art_;
        return ink_;
    }

    function setUp() public {
        CDPEngine = new CDPEngineInstance();
        CDPEngine.init("gold");
        CDPEngine.file("Line", rad(100 ether));
        CDPEngine.file("gold", "line", rad(100 ether));
    }
    function draw(bytes32 collateralType, uint dai) internal {
        CDPEngine.file("Line", rad(dai));
        CDPEngine.file(collateralType, "line", rad(dai));
        CDPEngine.file(collateralType, "spot", 10 ** 27 * 10000 ether);
        address self = address(this);
        CDPEngine.slip(collateralType, self,  10 ** 27 * 1 ether);
        CDPEngine.frob(collateralType, self, self, self, int(1 ether), int(dai));
    }
    function test_fold() public {
        address self = address(this);
        address ali  = address(bytes20("ali"));
        draw("gold", 1 ether);

        assertEq(tab("gold", self), rad(1.00 ether));
        CDPEngine.fold("gold", ali,   int(ray(0.05 ether)));
        assertEq(tab("gold", self), rad(1.05 ether));
        assertEq(CDPEngine.dai(ali),      rad(0.05 ether));
    }
}
