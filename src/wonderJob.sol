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
error ClientIsTakeOrder();
error OrderException();

contract WonderJob is WonderJobFundEscrowPool, Initializable, OwnableUpgradeable {

    using ECDSA for bytes32;
    using OrderExecutor for *;
    using UserManagement for UserManagement.UsersOperation;
    using OrderFeeFulfil for OrderFeeFulfil.FeeConfig;
    
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
        if (msg.value < orderPrice) revert InsufficientFunds(msg.value);

        uint256 nonce = getOrderNonce(msg.sender);

        if (_userOrders.getOrderServiceProvider(msg.sender, nonce, hash) != address(0)) revert OrderException();
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
        if (orderNonce > getOrderNonce(serviceProvider)) revert InvalidOrderNonce(orderNonce);
        bytes32 orderId = _userOrders.getOrderId(serviceProvider, orderNonce);
        if (_userOrders.getOrderServiceProvider(
                serviceProvider, 
                orderNonce,
                orderId
            ) == address(0)
            || _userOrders.getOrderServiceProvider(
                serviceProvider,
                orderNonce, 
                orderId
            ) != serviceProvider
        ) revert OrderException();

        if (!_usersOperation.getUserCustomer(msg.sender)) revert UserHasNoAuthorization();
        if (_userOrders.getOrderStatus(serviceProvider, orderNonce, orderId) & uint8(0x4) != 0) revert OrderInModify();
        if (_userOrders.getOrderClient(serviceProvider, orderNonce, orderId) != address(0)) revert OrderAccepted();
        
        require(getClientEscrowFundBalanceof(msg.sender) > 0, "The user escrow fund balance is zero");
        _userOrders.acceptOrder(serviceProvider, orderNonce, orderId, msg.sender);
    }

    function depositEscrowFundWithClient(uint128 escrowAmount) external payable {
        uint256 balance = getClientEscrowFundBalanceof(msg.sender);
        if (balance + escrowAmount < MIN_ESCROW_AMOUNT) revert InsufficientEscrowAmount(escrowAmount);
        _depositEscrowFundWithClient(escrowAmount);
    }

    function submitOrder(address serviceProvider, uint256 orderNonce) external {
        bytes32 orderId = _userOrders.getOrderId(serviceProvider, orderNonce);
        if (_userOrders.getOrderServiceProvider(
                serviceProvider, 
                orderNonce,
                orderId
            ) == address(0)
            || _userOrders.getOrderServiceProvider(
                serviceProvider,
                orderNonce,
                orderId
            ) != serviceProvider
        ) revert OrderException();

        if (!_usersOperation.getUserCustomer(msg.sender)) revert UserHasNoAuthorization();
        if (_userOrders.getOrderStatus(serviceProvider, orderNonce, orderId) & uint8(0x4) != 0) revert OrderInModify();
        if (_userOrders.getOrderClient(serviceProvider, orderNonce, orderId) != msg.sender) revert InvalidOrderClient();

        _userOrders.modiflyOrderStatus(serviceProvider, orderNonce, orderId, uint8(0x1));
    }

    function cancelOrder(address serviceProvider, uint256 orderNonce) external {
        bytes32 orderId = _userOrders.getOrderId(serviceProvider, orderNonce);
        if (_userOrders.getOrderStatus(serviceProvider, orderNonce, orderId) & uint8(0x4) != 0) revert OrderInModify();

        _userOrders.setCancelOrderUser(serviceProvider, orderNonce, orderId, msg.sender);
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

    function disputeOrder() external {
        
    }

    function resolveisputeOrder() external {

    }

    function withdrowEscrowFundWithClient() external {
        if (_usersOperation.getTakeOrder(msg.sender)) revert ClientIsTakeOrder();
        _withdrowEscrowFundWithClient();
    }

    function setFee(bool enable) public {
        if (enable) feeConfig.setFeeOn(msg.sender); else feeConfig.setFilpFeeOn(msg.sender);
    }

    function getOrderNonce(address user) public view returns (uint256) {
        return _orderGenerator.getOrderNonce(user);
    }

    function getOrderId() public view returns (bytes32) {
        return _userOrders.getOrderId(msg.sender, getOrderNonce(msg.sender));
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

    receive() external payable {}
}