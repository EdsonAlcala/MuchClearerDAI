pragma solidity 0.5.12;

import "ds-test/test.sol";
import {DSToken} from "ds-token/token.sol";

import {CDPEngineInstance}     from "../CDPEngine.sol";
import {CollateralSellerContract} from "../liquidator.sol";

contract Hevm {
    function warp(uint256) public;
}

contract Guy {
    CollateralSellerContract liquidator;
    constructor(CollateralSellerContract flip_) public {
        liquidator = flip_;
    }
    function hope(address usr) public {
        CDPEngineInstance(address(liquidator.CDPEngine())).hope(usr);
    }
    function tend(uint id, uint tokensForSale, uint bid) public {
        liquidator.tend(id, tokensForSale, bid);
    }
    function dent(uint id, uint tokensForSale, uint bid) public {
        liquidator.dent(id, tokensForSale, bid);
    }
    function deal(uint id) public {
        liquidator.deal(id);
    }
    function try_tend(uint id, uint tokensForSale, uint bid)
        public returns (bool ok)
    {
        string memory sig = "tend(uint256,uint256,uint256)";
        (ok,) = address(liquidator).call(abi.encodeWithSignature(sig, id, tokensForSale, bid));
    }
    function try_dent(uint id, uint tokensForSale, uint bid)
        public returns (bool ok)
    {
        string memory sig = "dent(uint256,uint256,uint256)";
        (ok,) = address(liquidator).call(abi.encodeWithSignature(sig, id, tokensForSale, bid));
    }
    function try_deal(uint id)
        public returns (bool ok)
    {
        string memory sig = "deal(uint256)";
        (ok,) = address(liquidator).call(abi.encodeWithSignature(sig, id));
    }
    function try_tick(uint id)
        public returns (bool ok)
    {
        string memory sig = "tick(uint256)";
        (ok,) = address(liquidator).call(abi.encodeWithSignature(sig, id));
    }
    function try_yank(uint id)
        public returns (bool ok)
    {
        string memory sig = "yank(uint256)";
        (ok,) = address(liquidator).call(abi.encodeWithSignature(sig, id));
    }
}


contract Gal {}

contract Vat_ is CDPEngineInstance {
    function mint(address usr, uint amount) public {
        dai[usr] += amount;
    }
    function dai_balance(address usr) public view returns (uint) {
        return dai[usr];
    }
    bytes32 ilk;
    function set_ilk(bytes32 ilk_) public {
        ilk = ilk_;
    }
    function gem_balance(address usr) public view returns (uint) {
        return tokenCollateral[ilk][usr];
    }
}

contract FlipTest is DSTest {
    Hevm hevm;

    Vat_    CDPEngine;
    CollateralSellerContract liquidator;

    address ali;
    address bob;
    address daiIncomeReceiver;
    address usr = address(0xacab);

    function setUp() public {
        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        hevm.warp(604411200);

        CDPEngine = new Vat_();

        CDPEngine.init("gems");
        CDPEngine.set_ilk("gems");

        liquidator = new CollateralSellerContract(address(CDPEngine), "gems");

        ali = address(new Guy(liquidator));
        bob = address(new Guy(liquidator));
        daiIncomeReceiver = address(new Gal());

        Guy(ali).hope(address(liquidator));
        Guy(bob).hope(address(liquidator));
        CDPEngine.hope(address(liquidator));

        CDPEngine.slip("gems", address(this), 1000 ether);
        CDPEngine.mint(ali, 200 ether);
        CDPEngine.mint(bob, 200 ether);
    }
    function test_kick() public {
        liquidator.kick({ tokensForSale: 100 ether
                  , tab: 50 ether
                  , usr: usr
                  , daiIncomeReceiver: daiIncomeReceiver
                  , bid: 0
                  });
    }
    function testFail_tend_empty() public {
        // can't tend on non-existent
        liquidator.tend(42, 0, 0);
    }
    function test_tend() public {
        uint id = liquidator.kick({ tokensForSale: 100 ether
                            , tab: 50 ether
                            , usr: usr
                            , daiIncomeReceiver: daiIncomeReceiver
                            , bid: 0
                            });

        Guy(ali).tend(id, 100 ether, 1 ether);
        // bid taken from bidder
        assertEq(CDPEngine.dai_balance(ali),   199 ether);
        // daiIncomeReceiver receives payment
        assertEq(CDPEngine.dai_balance(daiIncomeReceiver),     1 ether);

        Guy(bob).tend(id, 100 ether, 2 ether);
        // bid taken from bidder
        assertEq(CDPEngine.dai_balance(bob), 198 ether);
        // prev bidder refunded
        assertEq(CDPEngine.dai_balance(ali), 200 ether);
        // daiIncomeReceiver receives excess
        assertEq(CDPEngine.dai_balance(daiIncomeReceiver),   2 ether);

        hevm.warp(now + 5 hours);
        Guy(bob).deal(id);
        // bob gets the winnings
        assertEq(CDPEngine.gem_balance(bob), 100 ether);
    }
    function test_tend_later() public {
        uint id = liquidator.kick({ tokensForSale: 100 ether
                            , tab: 50 ether
                            , usr: usr
                            , daiIncomeReceiver: daiIncomeReceiver
                            , bid: 0
                            });
        hevm.warp(now + 5 hours);

        Guy(ali).tend(id, 100 ether, 1 ether);
        // bid taken from bidder
        assertEq(CDPEngine.dai_balance(ali), 199 ether);
        // daiIncomeReceiver receives payment
        assertEq(CDPEngine.dai_balance(daiIncomeReceiver),   1 ether);
    }
    function test_dent() public {
        uint id = liquidator.kick({ tokensForSale: 100 ether
                            , tab: 50 ether
                            , usr: usr
                            , daiIncomeReceiver: daiIncomeReceiver
                            , bid: 0
                            });
        Guy(ali).tend(id, 100 ether,  1 ether);
        Guy(bob).tend(id, 100 ether, 50 ether);

        Guy(ali).dent(id,  95 ether, 50 ether);
        // plop the gems
        assertEq(CDPEngine.gem_balance(address(0xacab)), 5 ether);
        assertEq(CDPEngine.dai_balance(ali),  150 ether);
        assertEq(CDPEngine.dai_balance(bob),  200 ether);
    }
    function test_beg() public {
        uint id = liquidator.kick({ tokensForSale: 100 ether
                            , tab: 50 ether
                            , usr: usr
                            , daiIncomeReceiver: daiIncomeReceiver
                            , bid: 0
                            });
        assertTrue( Guy(ali).try_tend(id, 100 ether, 1.00 ether));
        assertTrue(!Guy(bob).try_tend(id, 100 ether, 1.01 ether));
        // high bidder is subject to minimumBidIncrease
        assertTrue(!Guy(ali).try_tend(id, 100 ether, 1.01 ether));
        assertTrue( Guy(bob).try_tend(id, 100 ether, 1.07 ether));

        // can bid by less than minimumBidIncrease at liquidator
        assertTrue( Guy(ali).try_tend(id, 100 ether, 49 ether));
        assertTrue( Guy(bob).try_tend(id, 100 ether, 50 ether));

        assertTrue(!Guy(ali).try_dent(id, 100 ether, 50 ether));
        assertTrue(!Guy(ali).try_dent(id,  99 ether, 50 ether));
        assertTrue( Guy(ali).try_dent(id,  95 ether, 50 ether));
    }
    function test_deal() public {
        uint id = liquidator.kick({ tokensForSale: 100 ether
                            , tab: 50 ether
                            , usr: usr
                            , daiIncomeReceiver: daiIncomeReceiver
                            , bid: 0
                            });

        // only after singleBidLifetime
        Guy(ali).tend(id, 100 ether, 1 ether);
        assertTrue(!Guy(bob).try_deal(id));
        hevm.warp(now + 4.1 hours);
        assertTrue( Guy(bob).try_deal(id));

        uint ie = liquidator.kick({ tokensForSale: 100 ether
                            , tab: 50 ether
                            , usr: usr
                            , daiIncomeReceiver: daiIncomeReceiver
                            , bid: 0
                            });

        // or after end
        hevm.warp(now + 44 hours);
        Guy(ali).tend(ie, 100 ether, 1 ether);
        assertTrue(!Guy(bob).try_deal(ie));
        hevm.warp(now + 1 days);
        assertTrue( Guy(bob).try_deal(ie));
    }
    function test_tick() public {
        // start an auction
        uint id = liquidator.kick({ tokensForSale: 100 ether
                            , tab: 50 ether
                            , usr: usr
                            , daiIncomeReceiver: daiIncomeReceiver
                            , bid: 0
                            });
        // check no tick
        assertTrue(!Guy(ali).try_tick(id));
        // run past the end
        hevm.warp(now + 2 weeks);
        // check not biddable
        assertTrue(!Guy(ali).try_tend(id, 100 ether, 1 ether));
        assertTrue( Guy(ali).try_tick(id));
        // check biddable
        assertTrue( Guy(ali).try_tend(id, 100 ether, 1 ether));
    }
    function test_no_deal_after_end() public {
        // if there are no bids and the auction ends, then it should not
        // be refundable to the creator. Rather, it ticks indefinitely.
        uint id = liquidator.kick({ tokensForSale: 100 ether
                            , tab: 50 ether
                            , usr: usr
                            , daiIncomeReceiver: daiIncomeReceiver
                            , bid: 0
                            });
        assertTrue(!Guy(ali).try_deal(id));
        hevm.warp(now + 2 weeks);
        assertTrue(!Guy(ali).try_deal(id));
        assertTrue( Guy(ali).try_tick(id));
        assertTrue(!Guy(ali).try_deal(id));
    }
    function test_yank_tend() public {
        uint id = liquidator.kick({ tokensForSale: 100 ether
                            , tab: 50 ether
                            , usr: usr
                            , daiIncomeReceiver: daiIncomeReceiver
                            , bid: 0
                            });

        Guy(ali).tend(id, 100 ether, 1 ether);
        // bid taken from bidder
        assertEq(CDPEngine.dai_balance(ali),   199 ether);
        assertEq(CDPEngine.dai_balance(daiIncomeReceiver),     1 ether);

        CDPEngine.mint(address(this), 1 ether);
        liquidator.yank(id);
        // bid is refunded to bidder from caller
        assertEq(CDPEngine.dai_balance(ali),            200 ether);
        assertEq(CDPEngine.dai_balance(address(this)),    0 ether);
        // gems go to caller
        assertEq(CDPEngine.gem_balance(address(this)), 1000 ether);
    }
    function test_yank_dent() public {
        uint id = liquidator.kick({ tokensForSale: 100 ether
                            , tab: 50 ether
                            , usr: usr
                            , daiIncomeReceiver: daiIncomeReceiver
                            , bid: 0
                            });
        Guy(ali).tend(id, 100 ether,  1 ether);
        Guy(bob).tend(id, 100 ether, 50 ether);
        Guy(ali).dent(id,  95 ether, 50 ether);

        // cannot yank in the dent phase
        assertTrue(!Guy(ali).try_yank(id));
    }
}
