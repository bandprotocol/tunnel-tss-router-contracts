# Setup

Following these steps will integrate your target contract with the BandChain tunnel system, enabling secure and verified data relaying from BandChain tunnels to your on-chain contract.

1. Deploy the Target Contract:
   Start by deploying your target contract. For instance, you can use the example provided in PacketConsumer.sol. This contract is designed to receive and process the relayed tunnel data.

2. Create a Tunnel Object in BandChain:
   In the BandChain ecosystem, create a tunnel object by specifying the target contract’s address and the target chain. Once created, the BandChain system will generate a unique tunnelID that identifies this tunnel.

3. Configure the Target Contract:
   With the tunnelID in hand, set it on your deployed target contract. This step links the target contract to the specific tunnel in BandChain, ensuring that incoming messages are correctly routed.

4. Activate the Account:
   To start processing messages, activate the target account. This can be done by calling the activate function either directly on the target contract (using `PacketConsumer.activate`) or via the `TunnelRouter.activate` method. Activation is essential for enabling message relaying. You may need to deposit tokens into the account as well (providing eth within the transaction).

5. Verify Account Activation:
   Finally, confirm that the account is active by querying the `TunnelRouter.tunnelInfo(tunnelId, address)` function. This verification step ensures that the tunnel and target contract are properly configured and ready to receive data.
