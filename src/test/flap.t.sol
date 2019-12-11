pragma solidity 0.5.12;

import "ds-test/test.sol";
import {DSToken} from "ds-token/token.sol";
import "../buyCollateral.sol";
import "../CDPEngine.sol";


contract Hevm {
    function warp(uint256) public;
}

contract Guy {
    CollateralBuyerContract buyCollateral;
    constructor(CollateralBuyerContract flap_) public {
        buyCollateral = flap_;
        CDPEngineInstance(address(buyCollateral.CDPEngine())).hope(address(buyCollateral));
        DSToken(address(buyCollateral.tokenCollateral())).approve(address(buyCollateral));
    }
    function tend(uint id, uint tokensForSale, uint bid) public {
        buyCollateral.tend(id, tokensForSale, bid);
    }
    function deal(uint id) public {
        buyCollateral.deal(id);
    }
    function try_tend(uint id, uint tokensForSale, uint bid)
        public returns (bool ok)
    {
        string memory sig = "tend(uint256,uint256,uint256)";
        (ok,) = address(buyCollateral).call(abi.encodeWithSignature(sig, id, tokensForSale, bid));
    }
    function try_deal(uint id)
        public returns (bool ok)
    {
        string memory sig = "deal(uint256)";
        (ok,) = address(buyCollateral).call(abi.encodeWithSignature(sig, id));
    }
    function try_tick(uint id)
        public returns (bool ok)
    {
        string memory sig = "tick(uint256)";
        (ok,) = address(buyCollateral).call(abi.encodeWithSignature(sig, id));
    }
}

contract FlapTest is DSTest {
    Hevm hevm;

    CollateralBuyerContract buyCollateral;
    CDPEngineInstance     CDPEngine;
    DSToken tokenCollateral;

    address ali;
    address bob;

    function setUp() public {
        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        hevm.warp(604411200);

        CDPEngine = new CDPEngineInstance();
        tokenCollateral = new DSToken('');

        buyCollateral = new CollateralBuyerContract(address(CDPEngine), address(tokenCollateral));

        ali = address(new Guy(buyCollateral));
        bob = address(new Guy(buyCollateral));

        CDPEngine.hope(address(buyCollateral));
        tokenCollateral.approve(address(buyCollateral));

        CDPEngine.suck(address(this), address(this), 1000 ether);

        tokenCollateral.mint(1000 ether);
        tokenCollateral.setOwner(address(buyCollateral));

        tokenCollateral.push(ali, 200 ether);
        tokenCollateral.push(bob, 200 ether);
    }
    function test_kick() public {
        assertEq(CDPEngine.dai(address(this)), 1000 ether);
        assertEq(CDPEngine.dai(address(buyCollateral)),    0 ether);
        buyCollateral.kick({ tokensForSale: 100 ether
                  , bid: 0
                  });
        assertEq(CDPEngine.dai(address(this)),  900 ether);
        assertEq(CDPEngine.dai(address(buyCollateral)),  100 ether);
    }
    function test_tend() public {
        uint id = buyCollateral.kick({ tokensForSale: 100 ether
                            , bid: 0
                            });
        // tokensForSale taken from creator
        assertEq(CDPEngine.dai(address(this)), 900 ether);

        Guy(ali).tend(id, 100 ether, 1 ether);
        // bid taken from bidder
        assertEq(tokenCollateral.balanceOf(ali), 199 ether);
        // payment remains in auction
        assertEq(tokenCollateral.balanceOf(address(buyCollateral)),  1 ether);

        Guy(bob).tend(id, 100 ether, 2 ether);
        // bid taken from bidder
        assertEq(tokenCollateral.balanceOf(bob), 198 ether);
        // prev bidder refunded
        assertEq(tokenCollateral.balanceOf(ali), 200 ether);
        // excess remains in auction
        assertEq(tokenCollateral.balanceOf(address(buyCollateral)),   2 ether);

        hevm.warp(now + 5 weeks);
        Guy(bob).deal(id);
        // high bidder gets the tokensForSale
        assertEq(CDPEngine.dai(address(buyCollateral)),  0 ether);
        assertEq(CDPEngine.dai(bob), 100 ether);
        // income is burned
        assertEq(tokenCollateral.balanceOf(address(buyCollateral)),   0 ether);
    }
    function test_beg() public {
        uint id = buyCollateral.kick({ tokensForSale: 100 ether
                            , bid: 0
                            });
        assertTrue( Guy(ali).try_tend(id, 100 ether, 1.00 ether));
        assertTrue(!Guy(bob).try_tend(id, 100 ether, 1.01 ether));
        // high bidder is subject to minimumBidIncrease
        assertTrue(!Guy(ali).try_tend(id, 100 ether, 1.01 ether));
        assertTrue( Guy(bob).try_tend(id, 100 ether, 1.07 ether));
    }
    function test_tick() public {
        // start an auction
        uint id = buyCollateral.kick({ tokensForSale: 100 ether
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
}
