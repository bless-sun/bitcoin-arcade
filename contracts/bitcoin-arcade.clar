;; Title: BitcoinArcade NFT Smart Contract

;; Summary:
;; A Bitcoin-integrated gaming NFT platform built on Stacks Layer 2,
;; enabling players to earn, collect, and trade in-game assets
;; with Bitcoin-denominated rewards and value.

;; Description:
;; This contract implements an NFT platform for gaming assets that:
;;  - Creates and manages NFTs representing gaming achievements and assets
;;  - Tracks player scores, leaderboards, and earnings across compatible games
;;  - Distributes Bitcoin-denominated rewards based on gameplay achievements
;;  - Implements a seamless integration between on-chain assets and off-chain gameplay
;;  - Ensures compliance with BTC/Stacks ecosystem standards

;; Implement the NFT trait
(impl-trait .nft-trait.nft-trait)

;; Constants & Error Codes

;; Error definitions
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-PARAMETERS (err u101))
(define-constant ERR-NFT-NOT-FOUND (err u102))
(define-constant ERR-ALREADY-MINTED (err u103))
(define-constant ERR-INSUFFICIENT-FUNDS (err u104))
(define-constant ERR-TRANSFER-FAILED (err u105))
(define-constant ERR-REWARD-DISTRIBUTION-FAILED (err u106))

;; Valid rarity types
(define-constant VALID-RARITIES (list "common" "rare" "epic" "legendary"))

;; Data Variables

;; Contract owner
(define-data-var contract-owner principal tx-sender)

;; NFT collection name
(define-data-var collection-name (string-ascii 32) "BitcoinArcade Gaming Assets")

;; Token counter to generate unique IDs
(define-data-var last-token-id uint u0)

;; Reward system parameters
(define-data-var total-reward-pool uint u0)
(define-data-var reward-per-point uint u10)  ;; 10 sats per point as default

;; Data Maps

;; NFT metadata storage
(define-map nft-metadata 
  {token-id: uint}
  {
    name: (string-ascii 50),
    description: (string-ascii 200),
    rarity: (string-ascii 9),
    game-type: (string-ascii 50),
    minted-at: uint
  }
)

;; Leaderboard tracking
(define-map player-scores 
  {player: principal}
  {
    total-score: uint,
    last-updated: uint,
    total-rewards-earned: uint
  }
)

;; Non-Fungible Token Definition

;; Define the NFT asset
(define-non-fungible-token game-asset uint)

;; Private Helper Functions

;; Validate rarity type
(define-private (is-valid-rarity (rarity (string-ascii 9)))
  (is-some (index-of VALID-RARITIES rarity))
)

;; Validate game type
(define-private (is-valid-game-type (game-type (string-ascii 50)))
  (and 
    (> (len game-type) u0) 
    (<= (len game-type) u50)
  )
)

;; Validate principal (simple check to ensure it's not a zero-like principal)
(define-private (is-valid-principal (addr principal))
  (not (is-eq addr tx-sender))
)

;; Check if a principal is the owner of a specific NFT
(define-private (is-owner 
  (token-id uint)
  (user principal)
)
  (match (nft-get-owner? game-asset token-id)
    owner (is-eq user owner)
    false)
)

;; Initialize contract
(define-private (initialize)
  (begin
    ;; Set initial reward per point
    (var-set reward-per-point u10)
    
    ;; Set initial reward pool
    (var-set total-reward-pool u1000000)  ;; 1 million sats initial pool
    
    true
  )
)

;; NFT Core Functions

;; Mint a new game NFT
(define-public (mint-game-nft 
  (name (string-ascii 50))
  (description (string-ascii 200))
  (rarity (string-ascii 9))
  (game-type (string-ascii 50))
)
  (let 
    (
      (token-id (+ (var-get last-token-id) u1))
    )
    ;; Ensure only contract owner can mint initially
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    
    ;; Validate input parameters
    (asserts! (and 
      (> (len name) u0)
      (<= (len name) u50)
      (> (len description) u0)
      (<= (len description) u200)
      (is-valid-rarity rarity)
      (is-valid-game-type game-type)
    ) ERR-INVALID-PARAMETERS)
    
    ;; Mint the NFT
    (try! (nft-mint? game-asset token-id tx-sender))
    
    ;; Store metadata
    (map-set nft-metadata 
      {token-id: token-id}
      {
        name: name,
        description: description,
        rarity: rarity,
        game-type: game-type,
        minted-at: block-height
      }
    )
    
    ;; Update last token ID
    (var-set last-token-id token-id)
    
    ;; Return the new token ID
    (ok token-id)
  )
)
