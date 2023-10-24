// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {WonderJob} from "../src/wonderJob.sol";
import {WonderJobArbitration} from "../src/WonderJobArbitration.sol";
import {User} from "../src/libraries/UserManagement.sol";

contract WonderJobTest is Test {

    uint256 FORK_FIX_BLOCK_NUMBER = 184_053_08;
    uint256 GLOBAL_UNIX_TIMESTAMP = 1_697_978_416;

    string[5] RPC_LISTS = [
        "https://eth.llamarpc.com",         // Mainnet
        "https://arbitrum.llamarpc.com"     // Arbitrum
        "https://optimism.llamarpc.com"     // Optimism
        "https://polygon.llamarpc.com"      // Polygon
    ];
    uint256[5] FORK_RPC_LISTS;
    address userAddress;
    uint256 userAddressPrivateKey;

    WonderJob wonderJob;
    WonderJobArbitration IWonderJobArbitration;

    function setUp() public {
        (userAddress, userAddressPrivateKey) = makeAddrAndKey('userAddress');
        
        IWonderJobArbitration = new WonderJobArbitration();
        wonderJob = new WonderJob(address(IWonderJobArbitration));
    
        // /*========== MULIT FORK MAINNET TEST ==========**/
        FORK_RPC_LISTS[0] = vm.createFork(RPC_LISTS[0], FORK_FIX_BLOCK_NUMBER);
        //FORK_RPC_LISTS[1] = vm.createFork(RPC_LISTS[1], FORK_FIX_BLOCK_NUMBER);
        //FORK_RPC_LISTS[2] = vm.createFork(RPC_LISTS[2], FORK_FIX_BLOCK_NUMBER);
        //FORK_RPC_LISTS[3] = vm.createFork(RPC_LISTS[3], FORK_FIX_BLOCK_NUMBER);
    }

    /*//////////////////////////////////////////////////////////////////////////
                            USER MANAGEMENT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/
    function testCreateUser() public {
        //vm.selectFork(FORK_RPC_LISTS[0]);
        vm.warp(GLOBAL_UNIX_TIMESTAMP);
        User memory user = User(userAddress, true, false, false, GLOBAL_UNIX_TIMESTAMP);
        wonderJob.createUser(user);

        vm.startPrank(userAddress);
        user = wonderJob.getUserProfile();
        console.log("User adddress: %s", user.userAddress);
        console.log("User is a customer: %s", user.isCustomer);
        console.log("User is a serviceProvider: %s: ", user.isServiceProvider);
        console.log("User register status: %s", user.isRegistered);
        console.log("User register time: %s", user.creationTime);
        vm.stopPrank();
    }

    function testCreateUserExpectReverts() public {
        vm.warp(GLOBAL_UNIX_TIMESTAMP);
        User memory user = User(userAddress, true, true, false, GLOBAL_UNIX_TIMESTAMP);
        wonderJob.createUser(user);

        // Repeat register user
        // skip `USER_HAS_BEEN_CREATED_REVERT` reverted.
        vm.expectRevert();
        wonderJob.createUser(user);
    }


    /*//////////////////////////////////////////////////////////////////////////
                            ORDER OPERATION FUNCTIONS 
    //////////////////////////////////////////////////////////////////////////*/
    function testCreateOrder() public {
        (address createOrderUser, uint256 createOrderUserPrivateKey) = makeAddrAndKey('createOrderUser');
        vm.label(createOrderUser, "serviceProvider");
        vm.deal(createOrderUser, 1200 ether);
        User memory user = User(createOrderUser, true, true, true, GLOBAL_UNIX_TIMESTAMP);
        wonderJob.createUser(user);

        uint32 orderDeadline = uint32(GLOBAL_UNIX_TIMESTAMP) + uint32(1 days);
        uint128 orderPrice = 0.1 ether;
        bytes32 ipfsLink = bytes32(bytes("https://ipfs.io/ipfs/QmNZiPk974vDsPmQii3YbrMKfi12KTSNM7XMiYyiea4VYZ/example"));
        uint256 nonce = wonderJob.getOrderNonce();
        bytes32 digest = bytes32(abi.encodePacked(orderDeadline, orderPrice, ipfsLink, nonce));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(createOrderUserPrivateKey, digest);

        vm.startPrank(createOrderUser);
        wonderJob.createOrder(orderDeadline, orderPrice, ipfsLink, digest, v, r, s);
    }

    function testCreateOrderExpectReverts() public {

    }


}