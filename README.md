# BitcoinArcade NFT Smart Contract

## Stacks Layer 2 NFT-based Gaming Rewards Platform with Bitcoin Integration

## Overview

**BitcoinArcade** is a cutting-edge smart contract deployed on the **Stacks blockchain**, enabling seamless integration between gaming achievements and Bitcoin-denominated rewards. It provides a foundational framework for building blockchain-powered gaming experiences, where NFTs represent in-game assets, player scores are tracked on-chain, and users earn real value through gameplay.

> **Blockchain Layer**: [Stacks](https://www.stacks.co/)
> **Reward Currency**: Bitcoin (via synthetic reward simulation)
> **Token Standard**: Custom NFT with Clarity-defined trait

## Features

### NFT Gaming Assets

* Mint NFTs representing player achievements, items, or assets.
* Metadata includes: `name`, `description`, `rarity`, `game-type`, and `minted-at`.
* Supports rarity validation: `common`, `rare`, `epic`, `legendary`.

### Player Score Tracking

* On-chain leaderboard via `player-scores` map.
* Tracks `total-score`, `last-updated` block height, and `total-rewards-earned`.

### Bitcoin-Denominated Rewards

* Bitcoin-equivalent sats are simulated via the Stacks chain.
* Reward distribution logic based on gameplay scores and fixed rate per point.
* Contract maintains a centralized reward pool.

### On-chain + Off-chain Integration

* Built to support hybrid models: gameplay occurs off-chain, but results are validated and rewarded on-chain.
* Metadata URLs resolve to off-chain assets (e.g., images, 3D models, metadata JSON).

## Smart Contract Details

### NFT Trait Implementation

```clarity
(define-trait nft-trait ...)
```

Implements Clarity-based trait for:

* `get-owner`, `get-last-token-id`, `get-token-uri`, `transfer`

### NFT Functions

* `mint-game-nft(name, description, rarity, game-type)`
* `get-nft-metadata(token-id)`
* `transfer(token-id, sender, recipient)`
* `get-owner(token-id)`
* `get-token-uri(token-id)`

### Game Score Functions

* `record-player-score(player, score)`

  > Admin-only. Updates player’s score and calculates reward.

* `distribute-bitcoin-rewards(player)`

  > Admin-only. Simulates Bitcoin reward payout and resets reward record.

### Reward Pool Management

* `add-to-reward-pool(amount)`
* `get-reward-pool-balance()`

### Admin Controls

* `transfer-ownership(new-owner)`
* Deployment auto-runs `(initialize)` to configure pool and reward rate.

## Security & Access Control

| Function                     | Access Level   |
| ---------------------------- | -------------- |
| `mint-game-nft`              | Contract Owner |
| `record-player-score`        | Contract Owner |
| `distribute-bitcoin-rewards` | Contract Owner |
| `add-to-reward-pool`         | Contract Owner |
| `transfer-ownership`         | Contract Owner |
| `transfer`                   | NFT Owner      |

> Principal validations and bounds checks prevent abuse or malicious transfers.

## Constants & Configurations

| Constant            | Description                           |
| ------------------- | ------------------------------------- |
| `reward-per-point`  | 10 sats per point (default)           |
| `total-reward-pool` | Initially 1,000,000 sats              |
| `VALID-RARITIES`    | `common`, `rare`, `epic`, `legendary` |
| Max score input     | 10,000 points per call                |
| Max pool addition   | 1,000,000,000 sats                    |

## Deployment & Usage

### Deploying

Deploy via Clarity IDE or Stacks CLI. The `initialize` function is auto-run to configure default reward parameters.

### Testing & Simulation

* Use testnet/faucets to simulate BTC-equivalent reward flows.
* Customize `reward-per-point` manually by modifying contract logic.

### Integration

* Use off-chain game engines to call `record-player-score` post-match.
* Sync game results via oracle or admin relay to keep gameplay verifiable.

## Example Use Case

> **Scenario**: A player finishes a round in an arcade shooter. The game sends their score to the smart contract via `record-player-score`. At regular intervals, the admin calls `distribute-bitcoin-rewards`, allowing players to claim Bitcoin-backed rewards directly based on on-chain records.

## Tech Stack

* **Language**: [Clarity](https://docs.stacks.co/docs/write-smart-contracts/clarity-overview)
* **Blockchain**: [Stacks](https://stacks.co/) (Layer 2 for Bitcoin)
* **NFT Standard**: Custom-compliant with Clarity NFT trait
* **Off-chain Integration**: Supports REST-based game engines and asset metadata storage (e.g., IPFS, Web2)

## Disclaimer

This contract **simulates** Bitcoin reward distribution via internal accounting on the Stacks chain. Actual BTC transfers require external Bitcoin integration mechanisms not included in this Clarity contract.
