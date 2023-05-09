// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import { TerraBioLabel } from "src/TerraBioLabel.sol";

contract TerraBioLabel_test is Test {
    TerraBioLabel internal label;

    string internal uri = "ipfs://fake-uri.com";

    address internal constant OWNER = address(501);

    address internal USER1 = address(1);
    address internal USER2 = address(2);
    address internal USER3 = address(3);
    address internal USER4 = address(4);
    address internal USER5 = address(5);

    function setUp() public {
        label = new TerraBioLabel("TB-Label", "TBL", OWNER);
    }

    function test_anyExternalFunc_OnlyOwner() public {
        vm.startPrank(USER1);
        vm.expectRevert("Ownable: caller is not the owner");
        label.mintLabel(USER2, uri);

        vm.expectRevert("Ownable: caller is not the owner");
        label.burnLabel(1);

        vm.expectRevert("Ownable: caller is not the owner");
        label.renewLabel(1, USER2, "newURI");

        vm.expectRevert("Ownable: caller is not the owner");
        label.migrateLabel(1, USER2);
    }

    function test_mintLabel_CanMint() public {
        vm.startPrank(OWNER);
        label.mintLabel(USER1, uri);

        assertEq(label.ownerOf(1), USER1);
        assertEq(label.tokenURI(1), uri);
        assertEq(uint256(label.labelStatus(1)), 1); // active
        assertEq(label.labelExpires(1), block.timestamp + 366 days);
    }

    function test_burnLabel_CanBurn() public {
        vm.startPrank(OWNER);
        label.mintLabel(USER1, uri);

        vm.warp(2 * 367 days);

        label.burnLabel(1);

        vm.expectRevert("ERC721: invalid token ID");
        label.ownerOf(1);
        vm.expectRevert("ERC721: invalid token ID");
        label.tokenURI(1);
        assertEq(uint256(label.labelStatus(1)), 0); // active
        assertEq(label.labelExpires(1), 0);
    }

    function test_burnLabel_CannotBurnActiveLabel() public {
        vm.startPrank(OWNER);
        label.mintLabel(USER1, uri);

        vm.expectRevert(abi.encodeWithSignature("StillValid(uint256,uint256)", 1, 1));
        label.burnLabel(1); // active

        vm.warp(400 days);
        vm.expectRevert(abi.encodeWithSignature("StillValid(uint256,uint256)", 1, 2));
        label.burnLabel(1); // outpassed
    }

    function test_renewLabel_CanRenew() public {
        vm.startPrank(OWNER);
        label.mintLabel(USER1, uri);
        label.mintLabel(USER3, uri);

        vm.warp(400 days);

        label.renewLabel(1, USER2, "newURI");
        label.renewLabel(2, USER3, "newURI");

        assertEq(label.ownerOf(1), USER2);
        assertEq(label.tokenURI(1), "newURI");
        assertEq(uint256(label.labelStatus(1)), 1); // active
        assertEq(label.labelExpires(1), block.timestamp + 366 days);

        assertEq(label.ownerOf(2), USER3);
        assertEq(label.tokenURI(2), "newURI");
        assertEq(uint256(label.labelStatus(2)), 1); // active
        assertEq(label.labelExpires(2), block.timestamp + 366 days);
    }

    function test_renewLabel_RenewOnlyWhenExpired() public {
        vm.startPrank(OWNER);
        label.mintLabel(USER1, uri);

        vm.expectRevert(abi.encodeWithSignature("CannotRenew(uint256,uint256)", 1, 1));
        label.renewLabel(1, USER2, "newURI"); // active

        vm.warp(2 * 367 days);
        vm.expectRevert(abi.encodeWithSignature("CannotRenew(uint256,uint256)", 1, 3));
        label.renewLabel(1, USER2, "newURI"); // invalid
    }

    function test_renewLabel_CannotLeaveSameURI() public {
        vm.startPrank(OWNER);
        label.mintLabel(USER1, uri);

        vm.warp(400 days);

        vm.expectRevert(abi.encodeWithSignature("NoMetadataUpdate(uint256)", 1));
        label.renewLabel(1, USER2, uri);
    }

    function test_migrateLabel_CanMigrate() public {
        vm.startPrank(OWNER);
        label.mintLabel(USER1, uri);
        label.migrateLabel(1, USER2);

        assertEq(label.ownerOf(1), USER2);
        assertEq(label.tokenURI(1), uri);
        assertEq(uint256(label.labelStatus(1)), 1); // active
        assertEq(label.labelExpires(1), block.timestamp + 366 days);
    }

    function test_migrateLabel_CannotMigrateNotAttributed() public {
        vm.startPrank(OWNER);
        vm.expectRevert(abi.encodeWithSignature("NotAttributed(uint256)", 1));
        label.migrateLabel(1, USER2);
    }

    function test_transfer_UsersCannotTransfer() public {
        vm.prank(OWNER);
        label.mintLabel(USER1, uri);

        vm.prank(USER1);
        vm.expectRevert("Ownable: caller is not the owner");
        label.transferFrom(USER1, USER2, 1);
    }
}
