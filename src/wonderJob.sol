// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {User, UserManagement} from "./libraries/UserManagement.sol";
import {OrderExecutor, Order} from "./libraries/OrderExecutor.sol";
import {OrderFeeFulfil} from "./libraries/LibOrderFee.sol";
import "./WonderJobFundEscrowPool.sol";
import {ECDSA} from "./utils/ECDSA.sol";
import "./interfaces/IWonderJobArbitration.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/// *********************************************************************************************************
/// *                                                                                                       *
/// *                                                                                                       *
/// *     $$\      $$\                           $$\                        $$$$$\           $$\            *
/// *     $$ | $\  $$ |                          $$ |                       \__$$ |          $$ |           *
/// *     $$ |$$$\ $$ | $$$$$$\  $$$$$$$\   $$$$$$$ | $$$$$$\   $$$$$$\        $$ | $$$$$$\  $$$$$$$\       *
/// *     $$ $$ $$\$$ |$$  __$$\ $$  __$$\ $$  __$$ |$$  __$$\ $$  __$$\       $$ |$$  __$$\ $$  __$$\      *
/// *     $$$$  _$$$$ |$$ /  $$ |$$ |  $$ |$$ /  $$ |$$$$$$$$ |$$ |  \__|$$\   $$ |$$ /  $$ |$$ |  $$ |     *
/// *     $$$  / \$$$ |$$ |  $$ |$$ |  $$ |$$ |  $$ |$$   ____|$$ |      $$ |  $$ |$$ |  $$ |$$ |  $$ |     *
/// *     $$  /   \$$ |\$$$$$$  |$$ |  $$ |\$$$$$$$ |\$$$$$$$\ $$ |      \$$$$$$  |\$$$$$$  |$$$$$$$  |     *
/// *     \__/     \__| \______/ \__|  \__| \_______| \_______|\__|       \______/  \______/ \_______/      *
/// *                                                                                                       *
/// *                                                                                                       *
/// *********************************************************************************************************
error UserHasNoAuthorization();
error InvalidSignature(bytes32 signatureHash);
error OrderInModify();
error OrderAccepted();
error InvalidOrderNonce(uint256 orderNonce);
error InvalidOrderClient();
error InsufficientEscrowAmount(uint128 escrowAmount);

contract WonderJob is WonderJobFundEscrowPool, Initializable, OwnableUpgradeable {

    using ECDSA for bytes32;
    using OrderExecutor for *;
    using UserManagement for UserManagement.UsersOperation;

    IWonderJobArbitration public immutable IWonderJobArbitrationCallback;
    UserManagement.UsersOperation private _usersOperation;
    OrderExecutor.OrderGenerator private _orderGenerator;
    OrderExecutor.UserOrders private _userOrders;
    OrderFeeFulfil.FeeConfig public feeConfig;

    constructor(address IWonderJobArbitrationAddress) WonderJobFundEscrowPool(1e14) initializer {
        __Ownable_init(msg.sender);
        IWonderJobArbitrationCallback = IWonderJobArbitration(IWonderJobArbitrationAddress);
    }

    function createUser(User calldata user) public {
        _usersOperation.createUser(user);
    }

    function getUserProfile() public view returns (User memory _user) {
        User memory user_ = User({
            userAddress: msg.sender,
            isCustomer: _usersOperation.getUserCustomer(msg.sender),
            isServiceProvider: _usersOperation.getUserServiceProvider(msg.sender),
            isRegistered: _usersOperation.getUserRegisterStatus(msg.sender),
            creationTime: _usersOperation.getUserCreationTime(msg.sender)
        });

        assembly {
            _user := user_
        }
    }

    function createOrder(
        uint32 orderDeadline, 
        uint128 orderPrice, 
        bytes32 ipfsLink,
        bytes32 hash,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external payable {
        if (!_usersOperation.getUserCustomer(msg.sender) || !_usersOperation.getUserServiceProvider(msg.sender)) revert UserHasNoAuthorization();
        //if (msg.value < orderPrice) revert InsufficientFunds(msg.value);
        uint256 nonce = getOrderNonce();

        if (msg.sender != hash.recover(v, r, s)) revert InvalidSignature(hash);
        _userOrders._createOrder(
            _orderGenerator,
            nonce,
            msg.sender,
            orderDeadline,
            orderPrice,
            ipfsLink,
            hash
        );

        _depositEscrowFund(orderPrice, hash);
    }

    function acceptOrder(address serviceProvider, uint256 orderNonce) external {
        uint256 nonce;
        if (orderNonce == _usersOperation.getOrderNonce()) {
            nonce = _usersOperation.getOrderNonce();
        } else if (orderNonce < _usersOperation.getOrderNonce()) {
            nonce = orderNonce;
        } else {
            revert InvaildOrderNonce(orderNonce);
        }

        bytes32 orderId = _usersOperation.getOrderId(msg.sender, nonce);
        if (!_usersOperation.getUserCustomer(msg.sender)) revert UserHasNoAuthorization();
        if (_usersOperation.getOrderStatus(msg.sender, nonce, orderId) & 0x400000 != 0) revert OrderInModify();
        if (_usersOperation.getOrderClient(msg.sender, nonce, orderId) != address(0)) revert OrderAccepted();
        
        require(getClientEscrowFundBalanceof(msg.sender) > 0, "The user escrow fund balance is zero");
        _userOperation.acceptOrder(serviceProvider, nonce, orderId, msg.sender);
    }

    function depositEscrowFundWithClient(uint128 escrowAmount) external payable {
        uint128 balance = getClientEscrowFundBalanceof(msg.sender);
        if (balance + escrowAmount < MIN_ESCROW_AMOUNT) revert InsufficientEscrowAmount(escrowAmount);
        _depositEscrowFundWithClient(escrowAmount);
    }

    function submitOrder(address serviceProvider, uint256 orderNonce) external {
        uint256 nonce;
        bytes32 orderId = _usersOperation.getOrderId(msg.sender, nonce);
        if (!_usersOperation.getUserCustomer(msg.sender)) revert UserHasNoAuthorization();
        if (_usersOperation.getOrderStatus(msg.sender, nonce, orderId) & 0x400000 != 0) revert OrderInModify();
        if (_usersOperation.getOrderClient(msg.sender, nonce, orderId) != msg.sender) revert InvalidOrderClient();

        _usersOperation.modiflyOrderStatus(serviceProvider, nonce, orderId, 4);
    }

    function cancelOrder(address serviceProvider, uint256 orderNonce) external {
        if (_usersOperation.getOrderStatus(msg.sender, nonce, orderId) & 0x400000 != 0) revert OrderInModify();
        bytes32 orderId = _usersOperation.getOrderId(msg.sender, nonce);

        _usersOperation.setCancelOrderUser(msg.sender);
        if (
            msg.sender == serviceProvider
            && msg.sender == _userOrders.getOrderServiceProvider(
                serviceProvider, 
                orderNonce, 
                orderId
            )
        ) _withdrowEscrowFund(orderId);

        Order memory order = _userOrders.getOrderSituationByServiceProvider(serviceProvider, orderNonce, orderId);
        try IWonderJobArbitrationCallback.orderValidatorCallWithFallback(msg.sender, order) returns (bool fallbackStatus) {
            assembly {
                if iszero(fallbackStatus) {
                    mstore(0x00, 0xa)
                    revert(0x00, 0x04)
                }
            }
        } catch (bytes memory err){
            revert(string(err));
        }

    }

    /// @dev Make the function implement 'payable' to eliminate-boundary-checks
    /// require(msg.value >= 0)
    function completeOrder(bytes32 orderId) external payable {
        uint256 completeRewardAmount;
        Order memory order = _userOrders.getOrderSituationByServiceProvider(msg.sender, _orderGenerator.getOrderNonce(msg.sender), orderId);
        if (feeConfig.getFeeOn()) {
            uint256 feeAmount;
            unchecked { 
                // Exercise caution with precision loss issue.
                feeAmount = (
                    order.totalPrice * feeConfig.getFeeScale()) / feeConfig.getfeeDecimal() ^ 1 == 0
                        ? OrderFeeFulfil.MINIMUM_PERCENT_PRECISION
                        : OrderFeeFulfil.MAXIMUM_PERCENT_PRECISION; 
                completeRewardAmount = order.totalPrice - feeAmount;
            }
            _sendValue(feeConfig.getFeeTo(), feeAmount);
        } else {
            completeRewardAmount = order.totalPrice;
        }

        _withdrowEscrowFund(orderId);
        _sendValue(order.client, completeRewardAmount);
        try IWonderJobArbitrationCallback.orderValidatorCallWithFallback(msg.sender, order) returns (bool fallbackStatus) {
            assembly {
                if iszero(fallbackStatus) {
                    mstore(0x00, 0xa)
                    revert(0x00, 0x04)
                }
            }
        } catch (bytes memory err){
            revert(string(err));
        }
    }

    function _sendValue(address to, uint256 amount) private {
        assembly {
            let s := call(gas(), to, amount, 0x00, 0x00, 0x00, 0x00)
            if iszero(s) {
                mstore(0x00, 0xb1c003de) // error `InsufficientSendValue()`
                revert(0x00, 0x04)
            }
        }
    }

    function getOrderNonce() public view returns (uint256) {
        return _orderGenerator.getOrderNonce(msg.sender);
    }

    receive() external payable {}
}