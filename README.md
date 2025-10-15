# CacaoNet - On-Chain Cocoa Supply Registry 🍫

## Overview

CacaoNet is a blockchain-based supply chain tracking system designed to verify fair-trade sourcing of cocoa. Built on Stacks using Clarity smart contracts, it provides transparent and immutable tracking of cocoa from farm to finished product.

## System Architecture

The CacaoNet system consists of two main smart contracts:

### 1. Supply Registry Contract (`supply-registry.clar`)
- **Primary Function**: Tracks cocoa batches throughout the supply chain
- **Key Features**:
  - Batch registration with origin details
  - Quality certifications (organic, fair-trade, rainforest-alliance)
  - Chain of custody tracking
  - Processing stage verification
  - Final product mapping

### 2. Farmer Verification Contract (`farmer-verification.clar`)
- **Primary Function**: Manages farmer credentials and certifications
- **Key Features**:
  - Farmer profile registration
  - Certification management (fair-trade, organic, etc.)
  - Farm location verification
  - Compliance status tracking
  - Authority-based verification system

## Core Functionality

### Batch Tracking Workflow
1. **Registration**: Farmers register new cocoa batches with origin information
2. **Certification**: Quality certifications are added by authorized parties
3. **Processing**: Each processing stage is recorded with timestamps
4. **Chain of Custody**: Ownership transfers are logged immutably
5. **Final Product**: Finished goods are linked to source batches

### Verification System
- **Multi-level Authorization**: Different roles (farmers, certifiers, processors)
- **Immutable Records**: All transactions permanently stored on blockchain
- **Transparency**: Public verification of fair-trade claims
- **Compliance**: Automated checks for certification requirements

## Data Structure

### Batch Information
- Unique batch ID
- Farmer identification
- Origin coordinates (latitude/longitude)
- Harvest date and quantity
- Quality grades and certifications
- Processing history
- Current ownership

### Farmer Profiles
- Farmer principal address
- Farm registration details
- Certification statuses
- Compliance ratings
- Historical performance

## Smart Contract Features

### Supply Registry Contract
- `register-batch`: Create new cocoa batch records
- `certify-batch`: Add quality certifications
- `transfer-ownership`: Record custody changes
- `add-processing-stage`: Log processing activities
- `get-batch-info`: Retrieve complete batch history
- `verify-certification`: Check certification validity

### Farmer Verification Contract
- `register-farmer`: Add new farmer to system
- `update-certification`: Modify farmer certifications
- `verify-farmer`: Check farmer credentials
- `add-compliance-record`: Record compliance activities
- `get-farmer-info`: Retrieve farmer profile
- `check-eligibility`: Verify fair-trade eligibility

## Benefits

### For Consumers
- **Transparency**: Verify fair-trade claims directly on blockchain
- **Trust**: Immutable proof of ethical sourcing
- **Information**: Access to complete supply chain history

### For Farmers
- **Fair Pricing**: Direct connection to premium markets
- **Reputation**: Build verified track record
- **Access**: Easier certification and compliance management

### For Brands
- **Compliance**: Automated verification of supply chain claims
- **Risk Management**: Real-time visibility into sourcing
- **Marketing**: Authentic sustainability stories

### For Certifiers
- **Efficiency**: Streamlined certification processes
- **Integrity**: Tamper-proof certification records
- **Scalability**: Automated compliance monitoring

## Technical Implementation

### Blockchain Platform
- **Network**: Stacks Blockchain
- **Language**: Clarity Smart Contract Language
- **Storage**: On-chain immutable records
- **Consensus**: Bitcoin-secured proof-of-transfer

### Data Types
- `uint`: Batch quantities, timestamps, ratings
- `principal`: User addresses, contract owners
- `tuple`: Complex data structures for batches and farmers
- `string-ascii`: Text data for descriptions and certifications
- `optional`: Nullable fields for flexible data

### Security Features
- **Access Control**: Role-based permissions
- **Input Validation**: Comprehensive data validation
- **Error Handling**: Robust error responses
- **Immutability**: Permanent record keeping

## Deployment Instructions

1. **Prerequisites**:
   - Clarinet CLI installed
   - Stacks wallet configured
   - Development environment setup

2. **Installation**:
   ```bash
   git clone <repository>
   cd CacaoNet
   npm install
   ```

3. **Testing**:
   ```bash
   clarinet check
   clarinet test
   ```

4. **Deployment**:
   ```bash
   clarinet deploy --network testnet
   ```

## API Reference

### Supply Registry Functions

#### `register-batch`
```clarity
(register-batch (batch-data tuple) (farmer principal))
```
Creates a new batch record with farmer verification.

#### `certify-batch`
```clarity
(certify-batch (batch-id uint) (certification string-ascii) (certifier principal))
```
Adds certification to existing batch.

#### `get-batch-info`
```clarity
(get-batch-info (batch-id uint))
```
Returns complete batch information and history.

### Farmer Verification Functions

#### `register-farmer`
```clarity
(register-farmer (farmer-data tuple))
```
Registers new farmer with initial profile data.

#### `verify-farmer`
```clarity
(verify-farmer (farmer principal))
```
Returns farmer verification status and certifications.

## Contributing

1. Fork the repository
2. Create feature branch
3. Implement changes with tests
4. Submit pull request

## License

MIT License - Open source for fair-trade transparency

## Contact

For questions or support, please contact the CacaoNet development team.

---

*Building trust in the cocoa supply chain, one block at a time.* 🌱