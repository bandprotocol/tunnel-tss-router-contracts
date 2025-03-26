# Overview

## What is Tunnel Router?

This smart contract project is designed to serve as a robust routing system within a decentralized environment. Its primary function is to enable a relayer to seamlessly transfer data produced by tunnels in BandChain to the appropriate target contract. The router interprets tunnel information—which includes the destination contract's identifier and signal prices being generated from the tunnel—and ensures that the data reaches its intended recipient accurately and securely.

Key aspects include:

- Router Functionality: Acts as an intermediary that captures and routes data produced by BandChain tunnels.
- Relayer Integration: Facilitates the role of a relayer, which retrieves data from BandChain and relays it to the on-chain target contract.
- Dynamic Target Identification: Utilizes tunnel-provided information to identify and forward data to the specific target contract, ensuring precise data delivery.

This architecture not only supports efficient data transmission between off-chain and on-chain systems but also reinforces the security and modularity of the overall contract ecosystem.
