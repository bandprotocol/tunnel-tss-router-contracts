# Data Flow

The data flow in this system is designed to securely and efficiently relay critical information from BandChain to on-chain contracts. This page describes related components and relaying process.

## Contract Component

Contract Components Summary

### Tunnel Router

Acts as the central hub that receives messages from relayers, decodes them, verifies their structure and sequence, and forwards the data to both the TssVerifier and the target contract. It also handles fee collection and account status management. Moreover, it plays a role in safeguarding the system by helping to monitor and enforce minimum balance thresholds for active target contracts.

### TssVerifier

Stores the active TSS group’s public key and is responsible for verifying the authenticity of the message signature. This verification is crucial to ensure that only messages signed by the trusted TSS group are processed.

### Vault

Manages funds within the system. It is used by the Tunnel Router to deduct processing fees from the target contract’s account. It allows user to deposit to and withdraw funds from the account.

## Process

![Data flow](https://i.imgur.com/MF5K3Hk.png)

Below is an explanation that outlines the complete data flow and details the roles of each contract component:

1. Message Generation by BandChain Tunnel:
   The process begins when a tunnel in BandChain produces a message. This message contains an encoded tunnel packet that includes vital information such as signal prices. Importantly, the data is signed by the active TSS (Threshold Signature Scheme) group and the group signature is created. This signature ensures that the message has been approved by a trusted group of signers.

2. Interaction with Tunnel Router:
   A relayer picks up the message from the tunnel and interacts with the Tunnel Router contract. The Tunnel Router decodes the incoming message and performs several critical checks:

   - Encoder Type: Verifies that the message format is correct.
   - Target Contract Activeness: Ensures that the on-chain target contract, as specified in the tunnel information, is active and eligible to receive the message.
   - Packet Sequence: Checks that the message sequence is valid, preventing replay or duplicate processing.

3. Verification via TssVerifier Contract:
   Once the Tunnel Router successfully decodes and preliminarily verifies the message, it forwards both the data and the signature to the TssVerifier contract.

   - The TssVerifier holds the active TSS group’s public key and uses it to confirm that the message signature is valid. This step ensures that the message was indeed signed by the authorized group, bolstering the trust and integrity of the relayed data.

4. Process the data via Target Contract:
   After successful verification, the validated message is forwarded to the specified target contract.

   - The target contract is then responsible for processing the message. Notably, if the target contract fails to execute the message (perhaps due to logic errors or other issues), the transaction is designed to not revert. Instead, the failure is handled gracefully and the process charges the target contract’s account to cover associated fees.

5. Fee Collection and Account Deactivation (if any):

   - The Vault contract manages the funds within the system. The Tunnel Router collects a fee for processing the message, which is deducted from the target contract’s account through the Vault.
   - Additionally, as a security and risk management measure, if the target contract’s balance falls below a predetermined threshold, the Tunnel Router automatically deactivates the target account. This step helps prevent further processing of messages until the account is sufficiently funded, mitigating potential misuse or exploitation.
