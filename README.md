# WonderJob

> [中文] [English]

## Table of Contents

- Introduction
- Features
- How It Works
- Security
- Contribution

---

## Introduction

WonderJob is a decentralized task hosting platform based on Web3 technology. It aims to provide a transparent and secure environment for users to post and accept various types of tasks.

---

## Features

### User Registration

Users can register as either Task Posters or Task Doers, or both.

功能描述：用户注册分为接单者和发单者，用户可以同时注册这两种类型。

### Task Posting

Only Task Posters can post tasks, specifying the task amount, deadline, etc. Task descriptions are stored in an IPFS link and the task funds are escrowed in a smart contract.

功能描述：发单者才可以发布任务，规定任务金额，期限等等，任务描述信息存储在 IPFS链接中，上链ipfs，并将任务资金托管到托管合约内。

### Task Acceptance

Task Doers can accept tasks but are required to deposit a certain amount (e.g., 500 USDT) as collateral.

功能描述：接单者接任务，但是需要缴纳平台设定的额度的金额，比如500USDT，用于接单的资金托管，违规时可以使用这笔押金进行处理。

### Task Cancellation

Both Task Posters and Task Doers can cancel tasks, with different consequences.

功能描述：取消任务分为发单者和接单者，如果是发单者取消任务，任务状态更改为已弃用，并返还托管任务的所有金额，如果是接单者取消任务，则不做任何操作，接单者会被扣除信用积分或者一定次数后禁止接单。

### Task Submission

Task Doers can submit tasks. Late submissions will result in a deduction of credit points.

功能描述：接单者提交任务时，如果超时提交，那么提交时会扣除一定信用分，按时提交的话，任务等待发单者审核。

### Task Completion

Upon satisfactory completion, the task amount is transferred to the Task Doer.

功能描述：如果任务没有问题，发单者点击完成，任务金额会发送到接单者地址上，如果平台开启费用开关，则会一部分费用金额划转到平台地址中。

---

## How It Works

- Smart Contract Architecture
- User Guide

## Security

- Audit Information

## Contribution

- Contribution Guidelines

---

Made with ❤️ by WonderJob Team
