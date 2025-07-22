# Equipment Lease Tokenization Smart Contract

A Clarity smart contract for the Stacks blockchain that enables tokenization of equipment for leasing purposes. This contract allows equipment owners to tokenize their assets, create lease agreements, and manage the entire leasing lifecycle on-chain.

## Features

### Core Functionality
- **Equipment Registration**: Register equipment with detailed metadata and tokenize ownership
- **Lease Management**: Create, manage, and complete lease agreements
- **Token System**: Fractional ownership through equipment tokens
- **Payment Handling**: Automated payment processing with deposits and fees
- **Rating System**: Equipment rating and review system
- **Multi-status Management**: Track equipment and lease status throughout lifecycle

### Key Capabilities
- Equipment tokenization with configurable supply
- Automated lease creation with duration limits
- Deposit handling with penalty mechanisms
- Platform fee collection
- Emergency pause functionality
- Operator authorization system
- Fund management (deposits/withdrawals)

## Contract Architecture

### Data Structures

#### Equipment Registry
- **Equipment ID**: Unique identifier for each piece of equipment
- **Owner**: Principal who owns the equipment
- **Metadata**: Name, description, category
- **Pricing**: Daily rate and required deposit
- **Status**: Available, Leased, Maintenance, Retired
- **Earnings**: Track total earnings and maintenance costs

#### Lease Agreements
- **Lease ID**: Unique identifier for each lease
- **Parties**: Lessee and lessor principals
- **Terms**: Duration, rates, amounts
- **Status**: Active, Completed, Terminated, Defaulted
- **Payments**: Track payment history

#### Token System
- **Equipment Tokens**: Fractional ownership tokens per equipment
- **User Balances**: STX balances for payments
- **Token Supply**: Total supply tracking per equipment

### Status Enums

#### Equipment Status
- `0` - Available for lease
- `1` - Currently leased
- `2` - Under maintenance
- `3` - Retired from service

#### Lease Status
- `0` - Active lease
- `1` - Completed successfully
- `2` - Terminated early
- `3` - Defaulted

## Public Functions

### Equipment Management

#### `register-equipment`
```clarity
(register-equipment name description category daily-rate deposit-required token-supply)
```
Register new equipment and mint initial tokens.

**Parameters:**
- `name`: Equipment name (max 100 chars)
- `description`: Detailed description (max 500 chars)
- `category`: Equipment category (max 50 chars)
- `daily-rate`: Daily rental rate in microSTX
- `deposit-required`: Security deposit amount
- `token-supply`: Initial token supply to mint

**Returns:** Equipment ID

#### `update-equipment-status`
```clarity
(update-equipment-status equipment-id new-status)
```
Update equipment status (owner only).

#### `emergency-pause-equipment`
```clarity
(emergency-pause-equipment equipment-id)
```
Emergency pause equipment (owner or authorized operator).

### Lease Management

#### `create-lease`
```clarity
(create-lease equipment-id duration)
```
Create a new lease agreement.

**Parameters:**
- `equipment-id`: ID of equipment to lease
- `duration`: Lease duration in seconds (max 1 year)

**Requirements:**
- Equipment must be available
- Sufficient balance for total cost + deposit
- Valid duration

**Returns:** Lease ID

#### `complete-lease`
```clarity
(complete-lease lease-id)
```
Complete an active lease and return deposit (lessee only).

#### `terminate-lease`
```clarity
(terminate-lease lease-id)
```
Terminate lease early with penalty (lessee, lessor, or operator).

### Token Operations

#### `transfer-equipment-tokens`
```clarity
(transfer-equipment-tokens equipment-id recipient amount)
```
Transfer equipment tokens between users.

### Financial Operations

#### `deposit-funds`
```clarity
(deposit-funds amount)
```
Deposit STX into contract for lease payments.

#### `withdraw-funds`
```clarity
(withdraw-funds amount)
```
Withdraw STX from contract balance.

### Rating System

#### `rate-equipment`
```clarity
(rate-equipment equipment-id rating)
```
Rate equipment (1-5 stars).

### Administrative Functions

#### `add-authorized-operator`
```clarity
(add-authorized-operator operator)
```
Add authorized operator (contract owner only).

#### `update-platform-fee-rate`
```clarity
(update-platform-fee-rate new-rate)
```
Update platform fee rate (max 10%, contract owner only).

## Read-Only Functions

### Information Retrieval
- `get-equipment-info(equipment-id)`: Get equipment details
- `get-lease-info(lease-id)`: Get lease agreement details
- `get-equipment-token-balance(equipment-id, holder)`: Get token balance
- `get-user-balance(user)`: Get STX balance
- `get-equipment-rating(equipment-id)`: Get equipment rating

### Calculations
- `calculate-lease-cost(daily-rate, duration)`: Calculate total lease cost
- `is-lease-overdue(lease-id)`: Check if lease is overdue
- `get-platform-fee-rate()`: Get current platform fee rate

## Error Codes

| Code | Constant | Description |
|------|----------|-------------|
| 100 | ERR-UNAUTHORIZED | Unauthorized access |
| 101 | ERR-NOT-FOUND | Resource not found |
| 102 | ERR-ALREADY-EXISTS | Resource already exists |
| 103 | ERR-INSUFFICIENT-BALANCE | Insufficient balance |
| 104 | ERR-LEASE-ACTIVE | Lease is active |
| 105 | ERR-LEASE-EXPIRED | Lease has expired |
| 106 | ERR-INVALID-AMOUNT | Invalid amount |
| 107 | ERR-INVALID-DURATION | Invalid duration |
| 108 | ERR-PAYMENT-OVERDUE | Payment is overdue |
| 109 | ERR-EQUIPMENT-NOT-AVAILABLE | Equipment not available |
| 110 | ERR-INVALID-EQUIPMENT-STATE | Invalid equipment state |

## Usage Example

### 1. Register Equipment
```clarity
(contract-call? .equipment-lease register-equipment 
  "Excavator CAT 320" 
  "Heavy duty excavator for construction projects" 
  "Construction" 
  u1000000 ;; 1 STX per day
  u5000000 ;; 5 STX deposit
  u1000000) ;; 1M tokens
```

### 2. Deposit Funds
```clarity
(contract-call? .equipment-lease deposit-funds u10000000) ;; 10 STX
```

### 3. Create Lease
```clarity
(contract-call? .equipment-lease create-lease u1 u604800) ;; 7 days
```

### 4. Complete Lease
```clarity
(contract-call? .equipment-lease complete-lease u1)
```

## Security Features

- **Access Control**: Owner-only functions and operator authorization
- **Balance Validation**: Comprehensive balance checking
- **Status Validation**: Equipment and lease status verification
- **Emergency Controls**: Pause functionality for equipment
- **Penalty System**: Early termination penalties
- **Deposit Protection**: Automated deposit handling

## Platform Economics

- **Platform Fee**: Configurable fee rate (default 2.5%, max 10%)
- **Deposit System**: Security deposits held in escrow
- **Token Economy**: Fractional ownership through equipment tokens
- **Penalty Mechanism**: 50% deposit penalty for early termination

## Deployment Considerations

1. **Initial Configuration**: Set appropriate platform fee rates
2. **Operator Setup**: Add trusted operators for emergency functions
3. **Token Economics**: Consider token supply strategies
4. **Gas Optimization**: Functions optimized for transaction costs