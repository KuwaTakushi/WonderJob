# Forge Document

## Forge全局命令
### 1. [生成gas快照](#生成gas快照) 
### 2. [时间戳](#时间戳)
### 3. [地址操作](#地址操作)
### 4. [测试类型](#模糊测试)
### 5. [设置余额](#设置余额)
---

### 生成gas快照
```solidity
// 生成基本gas快照
forge snapshot

// 指定某个文件进行gas快照
forge snapshot --snap <FILE_NAME>

// 生成gas快照并按升序对gas结果排序
forge snapshot --asc 

// 当前快照文件与最新更改进行对比，gas是否优化减少
forge snapshot --diff
```



### 时间戳
```solidity
// 向前跳过block.timestamp指定的秒数
function test_MockSkipBlockTimestamp() public {
    require(block.timestamp == 0)
    assertEq(block.timestamp, 0);

    // 跳过3600秒，也就是1小时
    skip(3600);

    // require(block.timestamp == 3600);
    assertEq(block.timestamp, 3600);
}

// 向后倒退block.timestamp 指定的秒数
function test_MockRewindBlockTimestamp() public {
    require(block.timestamp == 3600)
    assertEq(block.timestamp, 3600);

    // 跳过3600秒，也就是1小时
    rewind(3600);

    // require(block.timestamp == 0);
    assertEq(block.timestamp, 0);
}
```

### 地址操作
### **从派生的名字中创建地址**
可以理解为创建为地址创建一个name代称标签
```solidity
function test_MockMakeAddr() public {
    // 通过makeAddr函数指定某个地址为alice
    address alice = makeAddr('alice');
    // 0x328809bc894f92807417d2dad6b7c998c1afdac6
    emit log_address(alice);
}
```

### **从派生的名字中创建地址和私钥**
```solidity
function test_MockMakeAddrAndKey() public {
    // 通过akeAddrAndKey函数指定某个地址为alice
    (address alice, uint256 key) = makeAddrAndKey('alice');
    // 0x328809bc894f92807417d2dad6b7c998c1afdac6
    emit log_address(alice);

    // 私钥 705649389916609337.....
    emit log_uint(key);
}
```
### **为测试地址打上跟踪标签**
如果地址被标记，则测试跟踪中将显示标签而不是地址。
```solidity
function test_Label() public {
    // 为DAI代币地址打上标签
    vm.label(address(0x...), 'DAI');

    //第二种写法
    vm.label({ account: address(dai), newLabel: "DAI" });
}
```


## cheatCode作弊码
### 1. [模拟当前调用者msg.sender](#vm.prank模拟当前调用者)
### 2. [模拟上下文当前调用者msg.sender](#vm.startPrank和vm.stopPrank上下文环境改变当前调用者)

---

### vm.prank模拟一次当前调用者
```solidity
function test_MockMsgSender() public {
    // msg.sender
    // 同时也可以这样写vm.prank(address(1))
    vm.prank(0x30bE4D758d86cfb1Ae74Ae698f2CF4BA7dC8d693);
}
```


### vm.startPrank和vm.stopPrank上下文环境改变当前调用者
```solidity
function testMockMsgSender() public {
    //在某个Code片段中上下文影响更改当前调用者
    vm.startPrank(0x30bE4D758d86cfb1Ae74Ae698f2CF4BA7dC8d693)
    code...
    vm.stopPrank()
}
```

---

### 测试类型

### 1. 模糊测试
Forge 允许您使用模糊测试。您需要做的就是创建一个带有输入变量的测试函数，Forge 将为您进行模糊测试。如果您需要有特定的约束，您可以将范围限制为特定的输入类型；或者，您可以使用 vm.assume 消除单个值和/或取模以将输入限制在精确范围内。

常用的模糊测试函数

- vm.bound
    - function bound(uint256 x, uint256 min, uint256 max) public returns (uint256 result)
2. vm.assume 

- 特定的值范围
- 特定的输入类型

***Exampels:***
```solidity
function test_FuzzBoundTesting() public {

}
```
---

### 设置余额
将地址余额设置who为newBalance。

如果使用 的替代签名deal，那么我们可以另外指定 ERC20 代币地址，以及更新 的选项totalSupply。

**vm.deal**指定某个账户设置测试的ether
```solidity
// 设置Ether数量
function test_DealEther() public {
    address alice = makeAddr('alice');
    emit log_address(alice);
    // 设置alice地址 1个eth的数量
    vm.deal(alice, 1 ether);

    /**
     * 也可以这样写
      * vm.deal({ account: alice, newBalance: 1 ether });
     */
    log_uint256(alice.balance);
}


// 设置Token数量
import "stdUints.sol";

function test_DealERC20_Token() public {
    address alice = makeAddr("alice");
    emit log_address(alice);
    // 从DAI地址发送alice地址 18wei数量的Dai代币
    deal(address(DAI), alice, 1 ether);
    /**
     * 也可以这样写
      * deal({ token: address(DAI), to: address(alice), give: 1 ether });
     */
    log_uint256(address(DAI).balanceOf(alice));
}
```