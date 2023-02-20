# Future-Bridge-Prototype (FPB)

<div align="center">

![logo](docs/static/img/logo.svg)

[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![test](https://github.com/bandprotocol/future-bridge-prototype/actions/workflows/test.yml/badge.svg)](https://github.com/bandprotocol/future-bridge-prototype/actions/workflows/test.yml)

</div>

**Disclaimer:** This project is still in its early stages of development and is considered a prototype. Please refrain from using it in production.

The FBP is a new relaying scheme that connects EVM networks with
the Band protocol's chain in a more efficient way than the current 
Bridge smart contract. It is based on threshold signature technology
and a custom signing procedure that reduces the size of the proof and
the number of verification operations, resulting in significant gas 
savings.

---

## Background
The current Bridge smart contract contains a large number of EVM operations
for doing lite client verification, which causes the gas used in the 
verification to be extremely high. This is mainly due to storing and 
reading validators with voting power, verifying numerous signatures, 
Merkle trees hashing, and Tendermint's struct encoding. 
To address this issue, the FBP was developed.

## Installation
First (if you don't have Foundry) run the command below to get foundryup,
the Foundry toolchain installer:
```sh
curl -L https://foundry.paradigm.xyz | bash
```

## Testing

```sh
forge test -vv
```

## Features
The FBP is built on threshold signature technology and a custom signing
procedure. This provides several advantages, including:

- Reduced gas usage: The custom signing procedure used in the FBP 
significantly reduces the amount of gas required for verification, 
resulting in cost savings for users.
- Enhanced decentralization: The threshold signature mechanism employed 
in the FBP further improves decentralization by eliminating the need for
a multisig wallet, which was previously utilized to regulate the Bridge
contract. This is because any parameter update can be accomplished with
a single threshold signature as proof, avoiding the requirement for 
numerous parties to sign off on changes. This makes the Future-Bridge
more decentralized and less reliant on a central authority, which is a 
vital feature for many blockchain users.

## Contributing
Contributions to the FBP are welcome and encouraged. If you have any suggestions or feedback, please open an issue or submit a pull request. We appreciate your contributions and look forward to working with you to make the FBP even better.
