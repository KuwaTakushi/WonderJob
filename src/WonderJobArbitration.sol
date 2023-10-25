// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "./interfaces/IWonderJobArbitration.sol";
import {Order} from "./libraries/OrderExecutor.sol";

struct UserEstimate {
    uint32  creditScore;  // [32: 256] creditScore offset: 0~3
    uint32  completedOrdersCount; // [64: 256] completedOrdersCount offset: 4~7
    uint32  disputedOrdersCount;  // [96: 256] disputedOrdersCount offset: 8~11
    uint32  cancelledOrdersCount; // [128： 256] cancelledOrdersCount offset: 12~15
    uint32  totalSpent;  // [160: 256] totalSpent offset: 16~19
    uint32  totalEarned; // [192: 256] totalEarned offset: 20~23

    bool    isBlockListedUser; // isBlockListedUser offset: 24~27
}

contract WonderJobArbitration is IWonderJobArbitration {

    error InsufficientCreitScore(uint256 creitScore);
    error CreditScoreIsZero();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                   😈😈CREDIT PUNISHMENT                   */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    uint256 public constant MIN_CREIT_SCORE_FALLBACK = 10;
    uint256 public constant CANCEL_ORDER_PUNISHMENT_SCORE = 2;
    uint256 public constant TIMEOUT_ORDER_PUNISHMENT_SCORE = 5;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      👼👼CREDIT REWARD                    */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    uint256 public constant FIRST_TIME_COMPLETE_ORDER_REWARD_REWARD = 5;

    uint256 public constant MIN_CREDIT_SCORE = 50;
    // 👑 WonderJob king
    uint256 public constant MAX_CREDIT_SCORE = 10000;
    uint256 public constant EXTRA_CREDIT_SCORE = 150;

    mapping (address serviceProvider => mapping (address client => Order)) private _disputeResolutionOrder;
    mapping (address anyUsers => UserEstimate) private _userEstimate;

    /// @dev event Transfer(address indexed sender, address indexed receiver, uint256 amount); 
    bytes32 constant transferHash = 0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef;


    function initializeUserCreditScore() public pure returns (uint32 creditScore) {
        assembly {
            creditScore := MIN_CREDIT_SCORE
        }
    }

    function tryTransferCreditScore(address to, uint256 amount) public returns (bool) {
        assembly("memory-safe") {
            let memptr := mload(0x40)
            mstore(memptr, caller())
            mstore(add(memptr, 0x20), _userEstimate.slot)
            let fromSlot := keccak256(memptr, 0x40)
            let fromBalance := sload(add(fromSlot, 0))
            if lt(fromBalance, amount) {
                revert(0, 0)
            } 
            // require(msg.sender != to)
            if eq(caller(), to) { revert(0, 0) }

            sstore(fromSlot, sub(fromBalance, amount))            

            // Reload `to` memptr
            mstore(memptr, to)
            mstore(add(memptr, 0x20), _userEstimate.slot)
            let toSlot := keccak256(memptr, 0x40)
            let toBalance := sload(add(toSlot, 0))            
            sstore(toSlot, add(toBalance, amount))

            log3(0x00, 0x20, transferHash, caller(), to)
        }
        return true;
    }

    function orderValidatorCallWithFallback(address user, Order calldata params) public returns (bool fallbackStatus) {
        // Skip read from memory
        UserEstimate storage currencyUserEstimate = _userEstimate[user];
        UserEstimate storage clientOrderUserEstimate = _userEstimate[params.client];
        UserEstimate storage cancelOrderUserEstimate = _userEstimate[params.cancelOrderUser];

        if (currencyUserEstimate.creditScore < MIN_CREIT_SCORE_FALLBACK) revert CreditScoreIsZero();
        if (params.cancelOrderUser != address(0)) {            
            uint32 creditScore;
            assembly {
                creditScore := mload(add(CANCEL_ORDER_PUNISHMENT_SCORE, 32))
            }
            // TODO: overflow-safe
            cancelOrderUserEstimate.creditScore = cancelOrderUserEstimate.creditScore >= creditScore
                ? cancelOrderUserEstimate.creditScore - creditScore
                : 0;
        }

        if (params.orderStatus ^ 3 == 0) {            
            uint32 creditScore;
            assembly {
                creditScore := mload(add(TIMEOUT_ORDER_PUNISHMENT_SCORE, 32))
            }
            clientOrderUserEstimate.creditScore = clientOrderUserEstimate.creditScore >= creditScore
                ? clientOrderUserEstimate.creditScore - creditScore
                : 0;
        }

        if (user == params.serviceProvider) {
            if (clientOrderUserEstimate.completedOrdersCount == 0) {
                uint32 creditScore;
                assembly {
                    creditScore := mload(add(FIRST_TIME_COMPLETE_ORDER_REWARD_REWARD, 32))
                }
                unchecked {
                    clientOrderUserEstimate.creditScore += creditScore;
                }
            }
        }

        return true;
    }
}
