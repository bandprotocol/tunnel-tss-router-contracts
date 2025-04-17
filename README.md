# Tunnel TSS Router Contracts

<div align="center">

![logo](docs/static/img/logo.svg)

[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![test](https://github.com/bandprotocol/tunnel-tss-router-contracts/actions/workflows/test.yml/badge.svg)](https://github.com/bandprotocol/tunnel-tss-router-contracts/actions/workflows/test.yml)

</div>

The Tunnel-TSS-Router is an innovative relaying solution that connects EVM networks with Band Protocol's price feeds data more efficiently than the current Bridge smart contract. It leverages threshold signature technology and a custom signing procedure to minimize proof size and verification operations, resulting in significant gas savings.

## Background
The current Bridge smart contract requires extensive EVM operations for lite client verification, leading to high gas consumption. This inefficiency stems from several factors such as:

1. Storing and retrieving validators with voting power
2. Verifying multiple signatures
3. Computing Merkle tree hashes
4. Encoding Tendermint structures

These operations result in high gas costs and slower transaction processing. The Tunnel-TSS-Router addresses these issues by implementing a more efficient verification mechanism using threshold signatures.

## Installation
If you don't have Foundry installed, run the following command to install foundryup, the Foundry toolchain installer:
```sh
curl -L https://foundry.paradigm.xyz | bash
```

## Testing
Run the following command to execute tests:
```sh
forge test -vv
```

## Data Flow
The Tunnel-TSS-Router system consists of multiple coordinated components that work together to securely relay data:

1. A **Relayer** submits data to the `TunnelRouter`
2. The `TunnelRouter` decodes the message and verifies its sequence to prevent replay attacks
3. If the sequence is valid, the data and its signature are forwarded to the `TSSVerifier` for signature validation
4. After successful verification, the message is sent to the `Target Contract` for final processing
5. The `TunnelRouter` withdraws the relaying fee from the `Vault` and transfers it to the relayer
6. If the remaining balance drops below a configured threshold, the Target Contract is marked as **inactive** to prevent further relaying

## Features
Built on threshold signature technology and a custom signing procedure, the project offers several advantages:

1. 🔁 **Efficient Relaying Process**
    - The `TunnelRouter` maintains data integrity by decoding messages and validating sequences
    - The `TSSVerifier` securely validates data authenticity using threshold signatures
    - Fees are automatically withdrawn from the `Vault` and paid to the relayer
    - Account owners can securely withdraw tokens from the `Vault`.

2. ✅ **Reduced Gas Usage**
    - Compact threshold signature scheme minimizes on-chain verification logic
    - Eliminates the need to verify multiple individual signatures

3. ⚖️ **Flexible Fee Models**
    - Supports both GasPrice and PriorityFee models
    - Ensures fair and flexible compensation for relayers across different network conditions
    - Vault-based system manages relayer deposits and withdrawals

4. 🛡️ **Robust Security**
    - Uses TSS to guarantee data integrity and authenticity
    - Prevents unauthorized withdrawals through vault safeguards
    - Sequence tracking prevents message replay and duplication
    - Deactivation logic protects underfunded target contracts from exploitation

5. 🏛️ **Enhanced Decentralization**
    - Eliminates the need for centralized multisig validators

## Contribution
We welcome and encourage contributions to the project. If you have suggestions or feedback, please open an issue or submit a pull request. We appreciate your contributions and look forward to collaborating to improve the Tunnel-TSS-Router.
