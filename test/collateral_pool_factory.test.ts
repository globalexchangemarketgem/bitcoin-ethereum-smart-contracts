require('dotenv').config({path:"../../.env"});

import { expect } from "chai";
import { ethers } from "hardhat";
import { Signer} from "ethers";

import { CollateralPoolFactory } from "../src/types/CollateralPoolFactory";
import { CollateralPoolFactory__factory } from "../src/types/factories/CollateralPoolFactory__factory";
import { ERC20 } from "../src/types/ERC20";
import { ERC20__factory } from "../src/types/factories/ERC20__factory";

import { takeSnapshot, revertProvider } from "./block_utils";

describe("CollateralPoolFactory", async () => {

    // Constants
    let ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";

    // Accounts
    let deployer: Signer;
    let signer1: Signer;

    // Contracts
    let collateralPoolFactory: CollateralPoolFactory;
    let erc20: ERC20;
    let _erc20: ERC20;

    let beginning: any;

    before(async () => {
        // Sets accounts
        [deployer, signer1] = await ethers.getSigners();

        // Deploys collateralPoolFactory contract
        const collateralPoolFactoryFactory = new CollateralPoolFactory__factory(deployer);
        collateralPoolFactory = await collateralPoolFactoryFactory.deploy(
            ZERO_ADDRESS
        );

        // Deploys erc20 contract
        const erc20Factory = new ERC20__factory(deployer);
        erc20 = await erc20Factory.deploy(
            "TestToken",
            "TT",
            0
        );
        _erc20 = await erc20Factory.deploy(
            "AnotherTestToken",
            "ATT",
            0
        );

    });

    describe("#createCollateralPool", async () => {

        it("Creates a collateral pool", async function () {
            // Takes a snapshot
            beginning = await takeSnapshot(signer1.provider);

            // Checks thta address is equal to zero
            expect(
                await collateralPoolFactory.getCollateralPoolByToken(erc20.address)
            ).to.equal(ZERO_ADDRESS);

            // Creates a collateral pool
            expect(
                await collateralPoolFactory.createCollateralPool(
                    erc20.address,
                    100
                )
            ).to.emit(collateralPoolFactory, 'CreateCollateralPool');
            
            // Checks total number of collateral pools
            expect(
                await collateralPoolFactory.allCollateralPoolsLength()
            ).to.equal(1);

            // Gets address of collateral pool
            let collateralPool = await collateralPoolFactory.allCollateralPools(0);

            // Checks correctness of collateral pool address
            expect(
                await collateralPoolFactory.getCollateralPoolByToken(erc20.address)
            ).to.equal(collateralPool);

            // Checks that collateral pool exists
            expect(
                await collateralPoolFactory.isCollateral(erc20.address)
            ).to.equal(true);
        })

        it("Reverts since collateral pool has been already created", async function () {
            await expect(
                collateralPoolFactory.createCollateralPool(
                    erc20.address,
                    50
                )
            ).to.revertedWith("CollateralPoolFactory: Collateral pool already exists");
        })

        it("Reverts since non-owner account calls the function", async function () {
            await revertProvider(signer1.provider, beginning);
            let collateralPoolFactorySigner1 = collateralPoolFactory.connect(signer1)
            await expect(
                collateralPoolFactorySigner1.createCollateralPool(
                    erc20.address,
                    100
                )
            ).to.reverted;
        })

        it("Reverts since collateral token address is zero", async function () {
            await revertProvider(signer1.provider, beginning);
            await expect(
                collateralPoolFactory.createCollateralPool(
                    ZERO_ADDRESS,
                    100
                )
            ).to.revertedWith("CollateralPoolFactory: Collateral token address is not valid");
        })

        it("Reverts since collateralization ratio is zero", async function () {
            await revertProvider(signer1.provider, beginning);
            await expect(
                collateralPoolFactory.createCollateralPool(
                    erc20.address,
                    0
                )
            ).to.revertedWith("CollateralPoolFactory: Collateralization ratio cannot be zero");
        })

    });

    describe("#removeCollateralPool", async () => {

        it("Removes a collateral pool", async function () {
            // Takes a snapshot
            beginning = await takeSnapshot(signer1.provider);

            // Creates two collateral pools
            await collateralPoolFactory.createCollateralPool(erc20.address, 100);
            await collateralPoolFactory.createCollateralPool(_erc20.address, 200);
            
            // Removes collateral pool
            expect(
                await collateralPoolFactory.removeCollateralPool(erc20.address, 0)
            ).to.emit(collateralPoolFactory, "RemoveCollateralPool");

            // Checks that collateral pool address is equal to zero
            expect(
                await collateralPoolFactory.getCollateralPoolByToken(erc20.address)
            ).to.equal(ZERO_ADDRESS);

            // Checks total number of collateral pools
            expect(
                await collateralPoolFactory.allCollateralPoolsLength()
            ).to.equal(1);

            // Checks that collateral pool doesn't exist
            expect(
                await collateralPoolFactory.isCollateral(erc20.address)
            ).to.equal(false);
        })

        it("Reverts since the index is out of range", async function () {
            // Creates a collateral pool
            await collateralPoolFactory.createCollateralPool(erc20.address, 100);
            
            // Removes collateral pool
            await expect(
                collateralPoolFactory.removeCollateralPool(erc20.address, 2)
            ).to.revertedWith("CollateralPoolFactory: Index is out of range");
        })

        it("Reverts since the collateral pool doesn't exist", async function () {
            await revertProvider(signer1.provider, beginning);
            
            // Removes collateral pool
            await expect(
                collateralPoolFactory.removeCollateralPool(erc20.address, 0)
            ).to.revertedWith("CollateralPoolFactory: Collateral pool does not exist");
        })

        it("Reverts since non-owner account calls the function", async function () {
            await revertProvider(signer1.provider, beginning);
            let collateralPoolFactorySigner1 = collateralPoolFactory.connect(signer1)
            await expect(
                collateralPoolFactorySigner1.removeCollateralPool(erc20.address, 0)
            ).to.reverted;
        })

    });

});