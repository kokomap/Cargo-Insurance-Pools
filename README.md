# 🚢 Cargo Insurance Pools

A decentralized insurance platform where shippers collectively pool resources to insure high-risk cargo routes on the Stacks blockchain.

## 🌟 Features

- **🏊 Pool Creation**: Create insurance pools for specific shipping routes
- **💰 Collective Funding**: Shippers contribute to shared insurance pools
- **📋 Claim Filing**: File claims for cargo damage or loss
- **🗳️ Democratic Voting**: Contributors vote on claim validity
- **⚡ Automated Payouts**: Approved claims receive automatic payouts
- **🔒 Secure Fund Management**: Deposit and withdraw funds safely

## 🚀 Getting Started

### Prerequisites
- Clarinet CLI installed
- Stacks wallet for testing

### Installation
```bash
git clone <repository>
cd cargo-insurance-pools
clarinet check
```

## 📖 Usage

### 1. 💸 Deposit Funds
```clarity
(contract-call? .Cargo-Insure-Pools deposit-funds u1000000)
```

### 2. 🏗️ Create Insurance Pool
```clarity
(contract-call? .Cargo-Insure-Pools create-pool 
  "Shanghai-Rotterdam" 
  u10000000    ; max pool size
  u100000      ; min contribution
  u1000000     ; max contribution
  u500)        ; premium rate (5%)
```

### 3. 🤝 Contribute to Pool
```clarity
(contract-call? .Cargo-Insure-Pools contribute-to-pool u1 u500000)
```

### 4. 📝 File Insurance Claim
```clarity
(contract-call? .Cargo-Insure-Pools file-claim 
  u1 
  u200000 
  "Container damaged during storm")
```

### 5. ✅ Vote on Claims
```clarity
(contract-call? .Cargo-Insure-Pools vote-on-claim u1 true)
```

### 6. ⚖️ Process Claims
```clarity
(contract-call? .Cargo-Insure-Pools process-claim u1)
```

### 7. 💳 Withdraw Funds
```clarity
(contract-call? .Cargo-Insure-Pools withdraw-funds u100000)
```

## 🔍 Read-Only Functions

### Pool Information
```clarity
(contract-call? .Cargo-Insure-Pools get-pool-info u1)
```

### Claim Details
```clarity
(contract-call? .Cargo-Insure-Pools get-claim-info u1)
```

### User Contributions
```clarity
(contract-call? .Cargo-Insure-Pools get-user-contribution u1 'SP1234...)
```

## 🎯 How It Works

1. **Pool Creation** 🏗️: Shippers create insurance pools for specific routes
2. **Contribution Phase** 💰: Multiple shippers contribute to pool funds
3. **Claim Filing** 📋: Contributors can file claims for cargo incidents
4. **Voting Period** 🗳️: Contributors vote on claim validity (144 blocks)
5. **Claim Processing** ⚡: Approved claims receive automatic payouts
6. **Fee Distribution** 💼: Platform takes small fee (2% default)

## 🔐 Security Features

- **Contributor Validation**: Only pool contributors can vote
- **Voting Power**: Voting power proportional to contribution amount
- **Time Limits**: Claims have voting deadlines
- **Balance Checks**: Prevents insufficient fund scenarios
- **Access Control**: Pool creators can deactivate pools

## 🛠️ Contract Functions

### Public Functions
- `create-pool`: Create new insurance pool
- `contribute-to-pool`: Add funds to existing pool
- `deposit-funds`: Deposit STX to contract
- `withdraw-funds`: Withdraw available balance
- `file-claim`: Submit insurance claim
- `vote-on-claim`: Vote on claim validity
- `process-claim`: Execute claim payout
- `set-platform-fee`: Update platform fee (owner only)
- `deactivate-pool`: Disable pool (creator only)

### Read-Only Functions
- `get-pool-info`: View pool details
- `get-claim-info`: View claim information
- `get-user-contribution`: Check user's pool contribution
- `get-platform-fee`: View current platform fee

## 📊 Data Structures

### Pool
- Route identifier
- Creator address
- Total pool funds
- Contribution limits
- Premium rate
- Active status

### Claim
- Associated pool ID
- Claimant address
- Claim amount
- Description
- Voting results
- Status and deadlines

## 🎭 Error Codes

- `u100`: Not authorized
- `u101`: Pool not found
- `u102`: Insufficient funds
- `u103`: Claim not found
- `u104`: Already voted
- `u105`: Invalid amount
- `u106`: Claim expired
- `u107`: Voting period active
- `u108`: Insufficient pool balance
- `u109`: Already contributed
- `u110`: Pool full

## 🤝 Contributing

1. Fork the repository
2. Create feature branch
3. Test changes with Clarinet
4. Submit pull request

## 📄 License

MIT License - see LICENSE file for details

## 🆘 Support

For questions or issues, please open a GitHub issue or contact the development team.

---

*Built with ❤️ for the Stacks ecosystem*
