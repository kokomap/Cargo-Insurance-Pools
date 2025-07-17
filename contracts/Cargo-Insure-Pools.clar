(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-POOL-NOT-FOUND (err u101))
(define-constant ERR-INSUFFICIENT-FUNDS (err u102))
(define-constant ERR-CLAIM-NOT-FOUND (err u103))
(define-constant ERR-ALREADY-VOTED (err u104))
(define-constant ERR-INVALID-AMOUNT (err u105))
(define-constant ERR-CLAIM-EXPIRED (err u106))
(define-constant ERR-VOTING-PERIOD-ACTIVE (err u107))
(define-constant ERR-INSUFFICIENT-POOL-BALANCE (err u108))
(define-constant ERR-ALREADY-CONTRIBUTED (err u109))
(define-constant ERR-POOL-FULL (err u110))

(define-data-var contract-owner principal tx-sender)
(define-data-var pool-counter uint u0)
(define-data-var claim-counter uint u0)
(define-data-var platform-fee uint u200)

(define-map pools
  uint
  {
    route: (string-ascii 100),
    creator: principal,
    total-pool: uint,
    max-pool: uint,
    min-contribution: uint,
    max-contribution: uint,
    premium-rate: uint,
    active: bool,
    created-at: uint
  }
)

(define-map pool-contributors
  {pool-id: uint, contributor: principal}
  {
    amount: uint,
    joined-at: uint
  }
)

(define-map claims
  uint
  {
    pool-id: uint,
    claimant: principal,
    amount: uint,
    description: (string-ascii 200),
    status: (string-ascii 20),
    votes-for: uint,
    votes-against: uint,
    created-at: uint,
    voting-deadline: uint
  }
)

(define-map claim-votes
  {claim-id: uint, voter: principal}
  {
    vote: bool,
    voting-power: uint
  }
)

(define-map user-balances
  principal
  uint
)

(define-private (get-pool-balance (pool-id uint))
  (default-to u0 (get total-pool (map-get? pools pool-id)))
)

(define-private (get-user-balance (user principal))
  (default-to u0 (map-get? user-balances user))
)

(define-private (calculate-voting-power (pool-id uint) (voter principal))
  (let ((contribution (map-get? pool-contributors {pool-id: pool-id, contributor: voter})))
    (match contribution
      contrib (get amount contrib)
      u0
    )
  )
)

(define-private (is-pool-contributor (pool-id uint) (user principal))
  (is-some (map-get? pool-contributors {pool-id: pool-id, contributor: user}))
)

(define-read-only (get-pool-info (pool-id uint))
  (map-get? pools pool-id)
)

(define-read-only (get-claim-info (claim-id uint))
  (map-get? claims claim-id)
)

(define-read-only (get-user-contribution (pool-id uint) (user principal))
  (map-get? pool-contributors {pool-id: pool-id, contributor: user})
)

(define-read-only (get-platform-fee)
  (var-get platform-fee)
)

(define-public (create-pool (route (string-ascii 100)) (max-pool uint) (min-contribution uint) (max-contribution uint) (premium-rate uint))
  (let ((pool-id (+ (var-get pool-counter) u1)))
    (asserts! (> max-pool u0) ERR-INVALID-AMOUNT)
    (asserts! (> min-contribution u0) ERR-INVALID-AMOUNT)
    (asserts! (> max-contribution min-contribution) ERR-INVALID-AMOUNT)
    (asserts! (<= premium-rate u10000) ERR-INVALID-AMOUNT)
    
    (map-set pools pool-id {
      route: route,
      creator: tx-sender,
      total-pool: u0,
      max-pool: max-pool,
      min-contribution: min-contribution,
      max-contribution: max-contribution,
      premium-rate: premium-rate,
      active: true,
      created-at: stacks-block-height
    })
    
    (var-set pool-counter pool-id)
    (ok pool-id)
  )
)

(define-public (contribute-to-pool (pool-id uint) (amount uint))
  (let ((pool-info (unwrap! (map-get? pools pool-id) ERR-POOL-NOT-FOUND))
        (current-contribution (map-get? pool-contributors {pool-id: pool-id, contributor: tx-sender}))
        (user-balance (get-user-balance tx-sender)))
    
    (asserts! (get active pool-info) ERR-NOT-AUTHORIZED)
    (asserts! (>= amount (get min-contribution pool-info)) ERR-INVALID-AMOUNT)
    (asserts! (<= amount (get max-contribution pool-info)) ERR-INVALID-AMOUNT)
    (asserts! (>= user-balance amount) ERR-INSUFFICIENT-FUNDS)
    (asserts! (is-none current-contribution) ERR-ALREADY-CONTRIBUTED)
    (asserts! (<= (+ (get total-pool pool-info) amount) (get max-pool pool-info)) ERR-POOL-FULL)
    
    (map-set pool-contributors {pool-id: pool-id, contributor: tx-sender} {
      amount: amount,
      joined-at: stacks-block-height
    })
    
    (map-set pools pool-id (merge pool-info {
      total-pool: (+ (get total-pool pool-info) amount)
    }))
    
    (map-set user-balances tx-sender (- user-balance amount))
    (ok true)
  )
)

(define-public (deposit-funds (amount uint))
  (let ((current-balance (get-user-balance tx-sender)))
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (map-set user-balances tx-sender (+ current-balance amount))
    (ok true)
  )
)

(define-public (withdraw-funds (amount uint))
  (let ((current-balance (get-user-balance tx-sender)))
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (asserts! (>= current-balance amount) ERR-INSUFFICIENT-FUNDS)
    (try! (as-contract (stx-transfer? amount tx-sender tx-sender)))
    (map-set user-balances tx-sender (- current-balance amount))
    (ok true)
  )
)

(define-public (file-claim (pool-id uint) (amount uint) (description (string-ascii 200)))
  (let ((pool-info (unwrap! (map-get? pools pool-id) ERR-POOL-NOT-FOUND))
        (claim-id (+ (var-get claim-counter) u1)))
    
    (asserts! (get active pool-info) ERR-NOT-AUTHORIZED)
    (asserts! (is-pool-contributor pool-id tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (asserts! (<= amount (get total-pool pool-info)) ERR-INSUFFICIENT-POOL-BALANCE)
    
    (map-set claims claim-id {
      pool-id: pool-id,
      claimant: tx-sender,
      amount: amount,
      description: description,
      status: "pending",
      votes-for: u0,
      votes-against: u0,
      created-at: stacks-block-height,
      voting-deadline: (+ stacks-block-height u144)
    })
    
    (var-set claim-counter claim-id)
    (ok claim-id)
  )
)

(define-public (vote-on-claim (claim-id uint) (support bool))
  (let ((claim-info (unwrap! (map-get? claims claim-id) ERR-CLAIM-NOT-FOUND))
        (pool-id (get pool-id claim-info))
        (voting-power (calculate-voting-power pool-id tx-sender)))
    
    (asserts! (is-pool-contributor pool-id tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (> voting-power u0) ERR-NOT-AUTHORIZED)
    (asserts! (<= stacks-block-height (get voting-deadline claim-info)) ERR-CLAIM-EXPIRED)
    (asserts! (is-none (map-get? claim-votes {claim-id: claim-id, voter: tx-sender})) ERR-ALREADY-VOTED)
    
    (map-set claim-votes {claim-id: claim-id, voter: tx-sender} {
      vote: support,
      voting-power: voting-power
    })
    
    (if support
      (map-set claims claim-id (merge claim-info {
        votes-for: (+ (get votes-for claim-info) voting-power)
      }))
      (map-set claims claim-id (merge claim-info {
        votes-against: (+ (get votes-against claim-info) voting-power)
      }))
    )
    
    (ok true)
  )
)

(define-public (process-claim (claim-id uint))
  (let ((claim-info (unwrap! (map-get? claims claim-id) ERR-CLAIM-NOT-FOUND))
        (pool-id (get pool-id claim-info))
        (pool-info (unwrap! (map-get? pools pool-id) ERR-POOL-NOT-FOUND))
        (claim-amount (get amount claim-info))
        (platform-fee-amount (/ (* claim-amount (var-get platform-fee)) u10000))
        (payout-amount (- claim-amount platform-fee-amount)))
    
    (asserts! (> stacks-block-height (get voting-deadline claim-info)) ERR-VOTING-PERIOD-ACTIVE)
    (asserts! (is-eq (get status claim-info) "pending") ERR-NOT-AUTHORIZED)
    
    (if (> (get votes-for claim-info) (get votes-against claim-info))
      (begin
        (asserts! (>= (get total-pool pool-info) claim-amount) ERR-INSUFFICIENT-POOL-BALANCE)
        
        (map-set claims claim-id (merge claim-info {status: "approved"}))
        
        (map-set pools pool-id (merge pool-info {
          total-pool: (- (get total-pool pool-info) claim-amount)
        }))
        
        (let ((claimant-balance (get-user-balance (get claimant claim-info))))
          (map-set user-balances (get claimant claim-info) (+ claimant-balance payout-amount))
        )
        
        (let ((owner-balance (get-user-balance (var-get contract-owner))))
          (map-set user-balances (var-get contract-owner) (+ owner-balance platform-fee-amount))
        )
        
        (ok true)
      )
      (begin
        (map-set claims claim-id (merge claim-info {status: "rejected"}))
        (ok false)
      )
    )
  )
)

(define-public (set-platform-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    (asserts! (<= new-fee u1000) ERR-INVALID-AMOUNT)
    (var-set platform-fee new-fee)
    (ok true)
  )
)

(define-public (deactivate-pool (pool-id uint))
  (let ((pool-info (unwrap! (map-get? pools pool-id) ERR-POOL-NOT-FOUND)))
    (asserts! (is-eq tx-sender (get creator pool-info)) ERR-NOT-AUTHORIZED)
    (map-set pools pool-id (merge pool-info {active: false}))
    (ok true)
  )
)
