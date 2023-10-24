// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Order} from "../libraries/OrderExecutor.sol";

interface IWonderJobArbitration {
    function initializeUserCreditScore() external  pure returns (uint32 creditScore);
    function orderValidatorCallWithFallback(address user, Order calldata params) external returns (bool fallbackStatus);
    function tryTransferCreditScore(address to, uint256 amount) external returns (bool);
}