pragma solidity 0.5.12;

import "ds-test/test.sol";

import {Flopper as Flop} from './flop.t.sol';
import {CollateralBuyerContract as purchaseCollateralContract} from './buyCollateral.t.sol';
import {TestVat as  CDPEngineInstance} from './CDPEngine.t.sol';
import {Vow}     from '../debtEngine.sol';

contract Hevm {
    function warp(uint256) public;
}

contract Gem {
    mapping (address => uint256) public balanceOf;
    function mint(address usr, uint rad) public {
        balanceOf[usr] += rad;
    }
}

contract VowTest is DSTest {
    Hevm hevm;

    CDPEngineInstance  CDPEngine;
    Vow  debtEngine;
    Flop flop;
    purchaseCollateralContract buyCollateral;
    Gem  gov;

    function setUp() public {
        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        hevm.warp(604411200);

        CDPEngine = new CDPEngineInstance();

        gov  = new Gem();
        flop = new Flop(address(CDPEngine), address(gov));
        buyCollateral = new purchaseCollateralContract(address(CDPEngine), address(gov));

        debtEngine = new Vow(address(CDPEngine), address(buyCollateral), address(flop));
        buyCollateral.addAuthorization(address(debtEngine));
        flop.addAuthorization(address(debtEngine));

        debtEngine.file("bump", rad(100 ether));
        debtEngine.file("sump", rad(100 ether));
        debtEngine.file("dump", 200 ether);

        CDPEngine.hope(address(flop));
    }

    function try_flog(uint era) internal returns (bool ok) {
        string memory sig = "flog(uint256)";
        (ok,) = address(debtEngine).call(abi.encodeWithSignature(sig, era));
    }
    function try_dent(uint id, uint tokensForSale, uint bid) internal returns (bool ok) {
        string memory sig = "dent(uint256,uint256,uint256)";
        (ok,) = address(flop).call(abi.encodeWithSignature(sig, id, tokensForSale, bid));
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
    function can_flap() public returns (bool) {
        string memory sig = "buyCollateral()";
        bytes memory data = abi.encodeWithSignature(sig);

        bytes memory can_call = abi.encodeWithSignature("try_call(address,bytes)", debtEngine, data);
        (bool ok, bytes memory success) = address(this).call(can_call);

        ok = abi.decode(success, (bool));
        if (ok) return true;
    }
    function can_flop() public returns (bool) {
        string memory sig = "flop()";
        bytes memory data = abi.encodeWithSignature(sig);

        bytes memory can_call = abi.encodeWithSignature("try_call(address,bytes)", debtEngine, data);
        (bool ok, bytes memory success) = address(this).call(can_call);

        ok = abi.decode(success, (bool));
        if (ok) return true;
    }

    uint constant ONE = 10 ** 27;
    function rad(uint amount) internal pure returns (uint) {
        return amount * ONE;
    }

    function suck(address who, uint amount) internal {
        debtEngine.fess(rad(amount));
        CDPEngine.init('');
        CDPEngine.suck(address(debtEngine), who, rad(amount));
    }
    function flog(uint amount) internal {
        suck(address(0), amount);  // suck dai into the zero address
        debtEngine.flog(now);
    }
    function heal(uint amount) internal {
        debtEngine.heal(rad(amount));
    }

    function test_change_flap_flop() public {
        purchaseCollateralContract newFlap = new purchaseCollateralContract(address(CDPEngine), address(gov));
        Flop newFlop = new Flop(address(CDPEngine), address(gov));

        newFlap.addAuthorization(address(debtEngine));
        newFlop.addAuthorization(address(debtEngine));

        assertEq(CDPEngine.can(address(debtEngine), address(buyCollateral)), 1);
        assertEq(CDPEngine.can(address(debtEngine), address(newFlap)), 0);

        debtEngine.file('flapper', address(newFlap));
        debtEngine.file('flopper', address(newFlop));

        assertEq(address(debtEngine.flapper()), address(newFlap));
        assertEq(address(debtEngine.flopper()), address(newFlop));

        assertEq(CDPEngine.can(address(debtEngine), address(buyCollateral)), 0);
        assertEq(CDPEngine.can(address(debtEngine), address(newFlap)), 1);
    }

    function test_flog_wait() public {
        assertEq(debtEngine.wait(), 0);
        debtEngine.file('wait', uint(100 seconds));
        assertEq(debtEngine.wait(), 100 seconds);

        uint tic = now;
        debtEngine.fess(100 ether);
        assertTrue(!try_flog(tic) );
        hevm.warp(now + tic + 100 seconds);
        assertTrue( try_flog(tic) );
    }

    function test_no_reflop() public {
        flog(100 ether);
        assertTrue( can_flop() );
        debtEngine.flop();
        assertTrue(!can_flop() );
    }

    function test_no_flop_pending_joy() public {
        flog(200 ether);

        CDPEngine.mint(address(debtEngine), 100 ether);
        assertTrue(!can_flop() );

        heal(100 ether);
        assertTrue( can_flop() );
    }

    function test_flap() public {
        CDPEngine.mint(address(debtEngine), 100 ether);
        assertTrue( can_flap() );
    }

    function test_no_flap_pending_sin() public {
        debtEngine.file("bump", uint256(0 ether));
        flog(100 ether);

        CDPEngine.mint(address(debtEngine), 50 ether);
        assertTrue(!can_flap() );
    }
    function test_no_flap_nonzero_woe() public {
        debtEngine.file("bump", uint256(0 ether));
        flog(100 ether);
        CDPEngine.mint(address(debtEngine), 50 ether);
        assertTrue(!can_flap() );
    }
    function test_no_flap_pending_flop() public {
        flog(100 ether);
        debtEngine.flop();

        CDPEngine.mint(address(debtEngine), 100 ether);

        assertTrue(!can_flap() );
    }
    function test_no_flap_pending_heal() public {
        flog(100 ether);
        uint id = debtEngine.flop();

        CDPEngine.mint(address(this), 100 ether);
        flop.dent(id, 0 ether, rad(100 ether));

        assertTrue(!can_flap() );
    }

    function test_no_surplus_after_good_flop() public {
        flog(100 ether);
        uint id = debtEngine.flop();
        CDPEngine.mint(address(this), 100 ether);

        flop.dent(id, 0 ether, rad(100 ether));  // flop succeeds..

        assertTrue(!can_flap() );
    }

    function test_multiple_flop_dents() public {
        flog(100 ether);
        uint id = debtEngine.flop();

        CDPEngine.mint(address(this), 100 ether);
        assertTrue(try_dent(id, 2 ether,  rad(100 ether)));

        CDPEngine.mint(address(this), 100 ether);
        assertTrue(try_dent(id, 1 ether,  rad(100 ether)));
    }
}
