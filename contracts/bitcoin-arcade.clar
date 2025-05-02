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

;; Define the NFT trait directly in this contract
(define-trait nft-trait
  (
    ;; Last token ID, limited to uint range
    (get-last-token-id () (response uint uint))
    
    ;; URI for token metadata
    (get-token-uri (uint) (response (optional (string-ascii 256)) uint))
    
    ;; Owner of the specified token
    (get-owner (uint) (response (optional principal) uint))
    
    ;; Transfer from owner to recipient
    (transfer (uint principal principal) (response bool uint))
  )
)

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
        minted-at: stacks-block-height
      }
    )
    
    ;; Update last token ID
    (var-set last-token-id token-id)
    
    ;; Return the new token ID
    (ok token-id)
  )
)

;; Transfer an NFT to another owner
(define-public (transfer 
  (token-id uint)
  (sender principal)
  (recipient principal)
)
  (begin
    ;; Validate recipient
    (asserts! (and 
      (not (is-eq sender recipient)) 
      (not (is-eq recipient (var-get contract-owner)))
      (is-valid-principal recipient)
    ) ERR-INVALID-PARAMETERS)
    
    ;; Ensure sender is the owner
    (asserts! (is-owner token-id sender) ERR-NOT-AUTHORIZED)
    
    ;; Perform transfer
    (try! (nft-transfer? game-asset token-id sender recipient))
    (ok true)
  )
)

;; Read-Only Functions 

;; Get NFT metadata
(define-read-only (get-nft-metadata (token-id uint))
  (map-get? nft-metadata {token-id: token-id})
)

;; Get current reward pool balance
(define-read-only (get-reward-pool-balance)
  (var-get total-reward-pool)
)

;; Implement NFT trait requirements
(define-read-only (get-last-token-id)
  (ok (var-get last-token-id))
)

(define-read-only (get-token-uri (token-id uint))
  (ok 
    (some 
      (concat 
        "https://bitcoinarcade.io/assets/" 
        (int-to-ascii token-id)
      )
    )
  )
)

(define-read-only (get-owner (token-id uint))
  (ok (nft-get-owner? game-asset token-id))
)

;; Game Reward System Functions

;; Record player score
(define-public (record-player-score 
  (player principal)
  (score uint)
)
  (let 
    (
      (current-score 
        (default-to 
          {total-score: u0, last-updated: u0, total-rewards-earned: u0}
          (map-get? player-scores {player: player})
        )
      )
      (new-total-score (+ (get total-score current-score) score))
    )
    ;; Ensure only contract owner can call this
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    
    ;; Validate score
    (asserts! (and 
      (> score u0) 
      (<= score u10000)  ;; Reasonable score limit
    ) ERR-INVALID-PARAMETERS)
    
    ;; Update player scores
    (map-set player-scores 
      {player: player}
      {
        total-score: new-total-score,
        last-updated: stacks-block-height,
        total-rewards-earned: (+ 
          (get total-rewards-earned current-score) 
          (* score (var-get reward-per-point))
        )
      }
    )
    
    (ok new-total-score)
  )
)

;; Distribute Bitcoin rewards
(define-public (distribute-bitcoin-rewards 
  (player principal)
)
  (let 
    (
      (player-score 
        (unwrap! 
          (map-get? player-scores {player: player}) 
          ERR-NFT-NOT-FOUND
        )
      )
      (total-reward (get total-rewards-earned player-score))
    )
    ;; Ensure only contract owner can distribute
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    
    ;; Ensure sufficient reward pool and valid reward amount
    (asserts! (and 
      (>= (var-get total-reward-pool) total-reward)
      (> total-reward u0)
    ) ERR-INSUFFICIENT-FUNDS)
    
    ;; Simulate Bitcoin reward transfer 
    ;; Note: Actual BTC transfer would require additional implementation
    (var-set total-reward-pool (- (var-get total-reward-pool) total-reward))
    
    ;; Reset player rewards after distribution
    (map-set player-scores 
      {player: player}
      {
        total-score: (get total-score player-score),
        last-updated: stacks-block-height,
        total-rewards-earned: u0
      }
    )
    
    (ok total-reward)
  )
)

;; Add funds to reward pool
(define-public (add-to-reward-pool (amount uint))
  (begin
    ;; Ensure only contract owner can add to pool
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    
    ;; Validate reward pool addition
    (asserts! (and 
      (> amount u0) 
      (<= amount u1000000000)  ;; Prevent extremely large additions
    ) ERR-INVALID-PARAMETERS)
    
    ;; Update reward pool
    (var-set total-reward-pool (+ (var-get total-reward-pool) amount))
    (ok true)
  )
)

;; Administrative Functions

;; Transfer contract ownership
(define-public (transfer-ownership (new-owner principal))
  (begin
    ;; Ensure only current owner can transfer
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    
    ;; Prevent transfer to zero or current owner principal
    (asserts! (and 
      (not (is-eq new-owner tx-sender))
      (is-valid-principal new-owner)
    ) ERR-INVALID-PARAMETERS)
    
    ;; Update contract owner
    (var-set contract-owner new-owner)
    (ok true)
  )
)

;; Run initialization on contract deploy
(initialize)