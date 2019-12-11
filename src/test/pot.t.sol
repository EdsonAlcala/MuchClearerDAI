pragma solidity 0.5.12;

import "ds-test/test.sol";
import {CDPEngineInstance} from '../CDPEngine.sol';
import {DaiSavingsRateContract} from '../daiSavingsRate.sol';

contract Hevm {
    function warp(uint256) public;
}

contract DSRTest is DSTest {
    Hevm hevm;

    CDPEngineInstance CDPEngine;
    DaiSavingsRateContract pot;

    address debtEngine;
    address self;
    address potb;

    function rad(uint wad_) internal pure returns (uint) {
        return wad_ * 10 ** 27;
    }
    function amount(uint rad_) internal pure returns (uint) {
        return rad_ / 10 ** 27;
    }

    function setUp() public {
        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        hevm.warp(604411200);

        CDPEngine = new CDPEngineInstance();
        pot = new DaiSavingsRateContract(address(CDPEngine));
        CDPEngine.addAuthorization(address(pot));
        self = address(this);
        potb = address(pot);

        debtEngine = address(bytes20("debtEngine"));
        pot.file("debtEngine", debtEngine);

        CDPEngine.suck(self, self, rad(100 ether));
        CDPEngine.hope(address(pot));
    }
    function test_save_0d() public {
        assertEq(CDPEngine.dai(self), rad(100 ether));

        pot.enableDSR(100 ether);
        assertEq(amount(CDPEngine.dai(self)),   0 ether);
        assertEq(pot.userSavingsBalance(self),      100 ether);

        pot.collectRate();

        pot.disableDSR(100 ether);
        assertEq(amount(CDPEngine.dai(self)), 100 ether);
    }
    function test_save_1d() public {
        pot.enableDSR(100 ether);
        pot.file("daiSavingsRate", uint(1000000564701133626865910626));  // 5% / day
        hevm.warp(now + 1 days);
        pot.collectRate();
        assertEq(pot.userSavingsBalance(self), 100 ether);
        pot.disableDSR(100 ether);
        assertEq(amount(CDPEngine.dai(self)), 105 ether);
    }
    function test_collectRate_multi() public {
        pot.enableDSR(100 ether);
        pot.file("daiSavingsRate", uint(1000000564701133626865910626));  // 5% / day
        hevm.warp(now + 1 days);
        pot.collectRate();
        assertEq(amount(CDPEngine.dai(potb)),   105 ether);
        pot.file("daiSavingsRate", uint(1000001103127689513476993127));  // 10% / day
        hevm.warp(now + 1 days);
        pot.collectRate();
        assertEq(amount(CDPEngine.sin(debtEngine)), 15.5 ether);
        assertEq(amount(CDPEngine.dai(potb)), 115.5 ether);
        assertEq(pot.totalSavingsRate(),          100   ether);
        assertEq(pot.rateAccumulator() / 10 ** 9, 1.155 ether);
    }
    function test_collectRate_multi_inBlock() public {
        pot.collectRate();
        uint timeOfLastCollectionRate = pot.timeOfLastCollectionRate();
        assertEq(timeOfLastCollectionRate, now);
        hevm.warp(now + 1 days);
        timeOfLastCollectionRate = pot.timeOfLastCollectionRate();
        assertEq(timeOfLastCollectionRate, now - 1 days);
        pot.collectRate();
        timeOfLastCollectionRate = pot.timeOfLastCollectionRate();
        assertEq(timeOfLastCollectionRate, now);
        pot.collectRate();
        timeOfLastCollectionRate = pot.timeOfLastCollectionRate();
        assertEq(timeOfLastCollectionRate, now);
    }
    function test_save_multi() public {
        pot.enableDSR(100 ether);
        pot.file("daiSavingsRate", uint(1000000564701133626865910626));  // 5% / day
        hevm.warp(now + 1 days);
        pot.collectRate();
        pot.disableDSR(50 ether);
        assertEq(amount(CDPEngine.dai(self)), 52.5 ether);
        assertEq(pot.totalSavingsRate(),          50.0 ether);

        pot.file("daiSavingsRate", uint(1000001103127689513476993127));  // 10% / day
        hevm.warp(now + 1 days);
        pot.collectRate();
        pot.disableDSR(50 ether);
        assertEq(amount(CDPEngine.dai(self)), 110.25 ether);
        assertEq(pot.totalSavingsRate(),            0.00 ether);
    }
    function test_fresh_rateAccumulator() public {
        uint timeOfLastCollectionRate = pot.timeOfLastCollectionRate();
        assertEq(timeOfLastCollectionRate, now);
        hevm.warp(now + 1 days);
        assertEq(timeOfLastCollectionRate, now - 1 days);
        pot.collectRate();
        pot.enableDSR(100 ether);
        assertEq(pot.userSavingsBalance(self), 100 ether);
        pot.disableDSR(100 ether);
        // if we disableDSR in the same transaction we should not earn DSR
        assertEq(amount(CDPEngine.dai(self)), 100 ether);
    }
    function testFail_stale_rateAccumulator() public {
        pot.file("daiSavingsRate", uint(1000000564701133626865910626));  // 5% / day
        pot.collectRate();
        hevm.warp(now + 1 days);
        pot.enableDSR(100 ether);
    }
    function test_file() public {
        hevm.warp(now + 1);
        pot.collectRate();
        pot.file("daiSavingsRate", uint(1));
    }
    function testFail_file() public {
        hevm.warp(now + 1);
        pot.file("daiSavingsRate", uint(1));
    }
}
