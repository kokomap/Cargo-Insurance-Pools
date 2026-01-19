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
(define-constant ERR-NO-REWARDS (err u111))
(define-constant ERR-REWARDS-ALREADY-CLAIMED (err u112))
(define-constant ERR-NOT-CONTRIBUTOR (err u113))
(define-constant ERR-EXCEEDS-MAX-CONTRIBUTION (err u114))
(define-constant ERR-EMERGENCY-COOLDOWN (err u115))
(define-constant ERR-POOL-NOT-IN-EMERGENCY (err u116))
(define-constant EMERGENCY-WITHDRAWAL-PENALTY u1000)
(define-constant EMERGENCY-COOLDOWN-BLOCKS u72)

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

(define-map pool-analytics
  uint
  {
    total-claims: uint,
    approved-claims: uint,
    rejected-claims: uint,
    total-claims-amount: uint,
    total-payouts: uint,
    avg-processing-time: uint,
    last-updated: uint
  }
)

(define-map pool-rewards
  uint
  {
    total-premium-collected: uint,
    total-rewards-distributed: uint,
    reward-rate: uint,
    last-distribution: uint
  }
)

(define-map contributor-rewards
  {pool-id: uint, contributor: principal}
  {
    total-earned: uint,
    last-claimed: uint,
    pending-rewards: uint
  }
)

(define-map pool-emergency-status
  uint
  {
    is-emergency: bool,
    declared-at: uint,
    declared-by: principal,
    reason: (string-ascii 100)
  }
)

(define-map emergency-withdrawals
  {pool-id: uint, contributor: principal}
  {
    last-withdrawal: uint,
    total-withdrawn: uint,
    penalty-paid: uint
  }
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

(define-private (get-pool-rewards (pool-id uint))
  (default-to 
    {
      total-premium-collected: u0,
      total-rewards-distributed: u0,
      reward-rate: u500,
      last-distribution: u0
    }
    (map-get? pool-rewards pool-id)
  )
)

(define-private (calculate-contributor-share (pool-id uint) (contributor principal))
  (let ((pool-info (unwrap-panic (map-get? pools pool-id)))
        (contributor-info (unwrap-panic (map-get? pool-contributors {pool-id: pool-id, contributor: contributor}))))
    (if (> (get total-pool pool-info) u0)
      (/ (* (get amount contributor-info) u10000) (get total-pool pool-info))
      u0
    )
  )
)

(define-private (calculate-pending-rewards (pool-id uint) (contributor principal))
  (let ((pool-rewards-info (get-pool-rewards pool-id))
        (contributor-share (calculate-contributor-share pool-id contributor))
        (contributor-rewards-info (map-get? contributor-rewards {pool-id: pool-id, contributor: contributor})))
    (match contributor-rewards-info
      existing-rewards
        (let ((share-of-unclaimed (/ (* (get total-premium-collected pool-rewards-info) contributor-share) u10000))
              (already-earned (get total-earned existing-rewards)))
          (if (> share-of-unclaimed already-earned)
            (- share-of-unclaimed already-earned)
            u0
          )
        )
      (/ (* (get total-premium-collected pool-rewards-info) contributor-share) u10000)
    )
  )
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

(define-read-only (get-pool-analytics (pool-id uint))
  (default-to 
    {
      total-claims: u0,
      approved-claims: u0,
      rejected-claims: u0,
      total-claims-amount: u0,
      total-payouts: u0,
      avg-processing-time: u0,
      last-updated: u0
    }
    (map-get? pool-analytics pool-id)
  )
)

(define-read-only (get-contributor-rewards (pool-id uint) (contributor principal))
  (map-get? contributor-rewards {pool-id: pool-id, contributor: contributor})
)

(define-read-only (get-pending-rewards (pool-id uint) (contributor principal))
  (if (is-pool-contributor pool-id contributor)
    (calculate-pending-rewards pool-id contributor)
    u0
  )
)

(define-read-only (get-pool-rewards-info (pool-id uint))
  (get-pool-rewards pool-id)
)

(define-read-only (get-pool-emergency-status (pool-id uint))
  (default-to 
    {
      is-emergency: false,
      declared-at: u0,
      declared-by: tx-sender,
      reason: ""
    }
    (map-get? pool-emergency-status pool-id)
  )
)

(define-read-only (get-emergency-withdrawal-info (pool-id uint) (contributor principal))
  (map-get? emergency-withdrawals {pool-id: pool-id, contributor: contributor})
)

(define-read-only (can-emergency-withdraw (pool-id uint) (contributor principal))
  (let ((emergency-status (get-pool-emergency-status pool-id))
        (withdrawal-info (map-get? emergency-withdrawals {pool-id: pool-id, contributor: contributor})))
    (and 
      (get is-emergency emergency-status)
      (is-pool-contributor pool-id contributor)
      (match withdrawal-info
        existing (>= (- stacks-block-height (get last-withdrawal existing)) EMERGENCY-COOLDOWN-BLOCKS)
        true
      )
    )
  )
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
    
    (map-set pool-analytics pool-id {
      total-claims: u0,
      approved-claims: u0,
      rejected-claims: u0,
      total-claims-amount: u0,
      total-payouts: u0,
      avg-processing-time: u0,
      last-updated: stacks-block-height
    })
    
    (map-set pool-rewards pool-id {
      total-premium-collected: u0,
      total-rewards-distributed: u0,
      reward-rate: u500,
      last-distribution: stacks-block-height
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
    
    (map-set contributor-rewards {pool-id: pool-id, contributor: tx-sender} {
      total-earned: u0,
      last-claimed: stacks-block-height,
      pending-rewards: u0
    })
    
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
    
    (let ((current-analytics (get-pool-analytics pool-id)))
      (map-set pool-analytics pool-id (merge current-analytics {
        total-claims: (+ (get total-claims current-analytics) u1),
        total-claims-amount: (+ (get total-claims-amount current-analytics) amount),
        last-updated: stacks-block-height
      }))
    )
    
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
        
        (let ((current-analytics (get-pool-analytics pool-id))
              (processing-time (- stacks-block-height (get created-at claim-info))))
          (map-set pool-analytics pool-id (merge current-analytics {
            approved-claims: (+ (get approved-claims current-analytics) u1),
            total-payouts: (+ (get total-payouts current-analytics) payout-amount),
            avg-processing-time: (/ (+ (* (get avg-processing-time current-analytics) (get approved-claims current-analytics)) processing-time) 
                                   (+ (get approved-claims current-analytics) u1)),
            last-updated: stacks-block-height
          }))
        )
        
        (ok true)
      )
      (begin
        (map-set claims claim-id (merge claim-info {status: "rejected"}))
        
        (let ((current-analytics (get-pool-analytics pool-id)))
          (map-set pool-analytics pool-id (merge current-analytics {
            rejected-claims: (+ (get rejected-claims current-analytics) u1),
            last-updated: stacks-block-height
          }))
        )
        
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

(define-public (distribute-premiums (pool-id uint) (premium-amount uint))
  (let ((pool-info (unwrap! (map-get? pools pool-id) ERR-POOL-NOT-FOUND))
        (pool-rewards-info (get-pool-rewards pool-id)))
    
    (asserts! (is-eq tx-sender (get creator pool-info)) ERR-NOT-AUTHORIZED)
    (asserts! (> premium-amount u0) ERR-INVALID-AMOUNT)
    (asserts! (get active pool-info) ERR-NOT-AUTHORIZED)
    
    (map-set pool-rewards pool-id (merge pool-rewards-info {
      total-premium-collected: (+ (get total-premium-collected pool-rewards-info) premium-amount),
      last-distribution: stacks-block-height
    }))
    
    (ok true)
  )
)

(define-public (claim-rewards (pool-id uint))
  (let ((pool-info (unwrap! (map-get? pools pool-id) ERR-POOL-NOT-FOUND))
        (pending-rewards (calculate-pending-rewards pool-id tx-sender))
        (user-balance (get-user-balance tx-sender))
        (current-rewards (map-get? contributor-rewards {pool-id: pool-id, contributor: tx-sender})))
    
    (asserts! (is-pool-contributor pool-id tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (> pending-rewards u0) ERR-NO-REWARDS)
    
    (match current-rewards
      existing-rewards
        (map-set contributor-rewards {pool-id: pool-id, contributor: tx-sender} (merge existing-rewards {
          total-earned: (+ (get total-earned existing-rewards) pending-rewards),
          last-claimed: stacks-block-height,
          pending-rewards: u0
        }))
      (map-set contributor-rewards {pool-id: pool-id, contributor: tx-sender} {
        total-earned: pending-rewards,
        last-claimed: stacks-block-height,
        pending-rewards: u0
      })
    )
    
    (let ((pool-rewards-info (get-pool-rewards pool-id)))
      (map-set pool-rewards pool-id (merge pool-rewards-info {
        total-rewards-distributed: (+ (get total-rewards-distributed pool-rewards-info) pending-rewards)
      }))
    )
    
    (map-set user-balances tx-sender (+ user-balance pending-rewards))
    (ok pending-rewards)
  )
)

(define-public (set-reward-rate (pool-id uint) (new-rate uint))
  (let ((pool-info (unwrap! (map-get? pools pool-id) ERR-POOL-NOT-FOUND))
        (pool-rewards-info (get-pool-rewards pool-id)))
    
    (asserts! (is-eq tx-sender (get creator pool-info)) ERR-NOT-AUTHORIZED)
    (asserts! (<= new-rate u5000) ERR-INVALID-AMOUNT)
    
    (map-set pool-rewards pool-id (merge pool-rewards-info {
      reward-rate: new-rate
    }))
    
    (ok true)
  )
)

(define-public (increase-contribution (pool-id uint) (additional-amount uint))
  (let ((pool-info (unwrap! (map-get? pools pool-id) ERR-POOL-NOT-FOUND))
        (contributor-info (unwrap! (map-get? pool-contributors {pool-id: pool-id, contributor: tx-sender}) ERR-NOT-CONTRIBUTOR))
        (user-balance (get-user-balance tx-sender))
        (new-total-contribution (+ (get amount contributor-info) additional-amount)))
    
    (asserts! (get active pool-info) ERR-NOT-AUTHORIZED)
    (asserts! (> additional-amount u0) ERR-INVALID-AMOUNT)
    (asserts! (>= user-balance additional-amount) ERR-INSUFFICIENT-FUNDS)
    (asserts! (<= new-total-contribution (get max-contribution pool-info)) ERR-EXCEEDS-MAX-CONTRIBUTION)
    (asserts! (<= (+ (get total-pool pool-info) additional-amount) (get max-pool pool-info)) ERR-POOL-FULL)
    
    (map-set pool-contributors {pool-id: pool-id, contributor: tx-sender} (merge contributor-info {
      amount: new-total-contribution
    }))
    
    (map-set pools pool-id (merge pool-info {
      total-pool: (+ (get total-pool pool-info) additional-amount)
    }))
    
    (map-set user-balances tx-sender (- user-balance additional-amount))
    (ok new-total-contribution)
  )
)

(define-public (decrease-contribution (pool-id uint) (reduction-amount uint))
  (let ((pool-info (unwrap! (map-get? pools pool-id) ERR-POOL-NOT-FOUND))
        (contributor-info (unwrap! (map-get? pool-contributors {pool-id: pool-id, contributor: tx-sender}) ERR-NOT-CONTRIBUTOR))
        (user-balance (get-user-balance tx-sender))
        (new-contribution (- (get amount contributor-info) reduction-amount)))
    
    (asserts! (get active pool-info) ERR-NOT-AUTHORIZED)
    (asserts! (> reduction-amount u0) ERR-INVALID-AMOUNT)
    (asserts! (>= (get amount contributor-info) reduction-amount) ERR-INVALID-AMOUNT)
    (asserts! (>= new-contribution (get min-contribution pool-info)) ERR-INVALID-AMOUNT)
    
    (map-set pool-contributors {pool-id: pool-id, contributor: tx-sender} (merge contributor-info {
      amount: new-contribution
    }))
    
    (map-set pools pool-id (merge pool-info {
      total-pool: (- (get total-pool pool-info) reduction-amount)
    }))
    
    (map-set user-balances tx-sender (+ user-balance reduction-amount))
    (ok new-contribution)
  )
)

(define-public (declare-emergency (pool-id uint) (reason (string-ascii 100)))
  (let ((pool-info (unwrap! (map-get? pools pool-id) ERR-POOL-NOT-FOUND)))
    (asserts! (or (is-eq tx-sender (get creator pool-info)) (is-eq tx-sender (var-get contract-owner))) ERR-NOT-AUTHORIZED)
    (asserts! (get active pool-info) ERR-NOT-AUTHORIZED)
    
    (map-set pool-emergency-status pool-id {
      is-emergency: true,
      declared-at: stacks-block-height,
      declared-by: tx-sender,
      reason: reason
    })
    
    (ok true)
  )
)

(define-public (resolve-emergency (pool-id uint))
  (let ((pool-info (unwrap! (map-get? pools pool-id) ERR-POOL-NOT-FOUND))
        (emergency-status (get-pool-emergency-status pool-id)))
    (asserts! (or (is-eq tx-sender (get creator pool-info)) (is-eq tx-sender (var-get contract-owner))) ERR-NOT-AUTHORIZED)
    (asserts! (get is-emergency emergency-status) ERR-POOL-NOT-IN-EMERGENCY)
    
    (map-set pool-emergency-status pool-id (merge emergency-status {
      is-emergency: false
    }))
    
    (ok true)
  )
)

(define-public (emergency-withdraw (pool-id uint))
  (let ((pool-info (unwrap! (map-get? pools pool-id) ERR-POOL-NOT-FOUND))
        (emergency-status (get-pool-emergency-status pool-id))
        (contributor-info (unwrap! (map-get? pool-contributors {pool-id: pool-id, contributor: tx-sender}) ERR-NOT-CONTRIBUTOR))
        (contribution-amount (get amount contributor-info))
        (penalty-amount (/ (* contribution-amount EMERGENCY-WITHDRAWAL-PENALTY) u10000))
        (withdrawal-amount (- contribution-amount penalty-amount))
        (user-balance (get-user-balance tx-sender))
        (existing-withdrawal (map-get? emergency-withdrawals {pool-id: pool-id, contributor: tx-sender})))
    
    (asserts! (get is-emergency emergency-status) ERR-POOL-NOT-IN-EMERGENCY)
    (asserts! (> contribution-amount u0) ERR-INVALID-AMOUNT)
    (asserts! (match existing-withdrawal
      existing (>= (- stacks-block-height (get last-withdrawal existing)) EMERGENCY-COOLDOWN-BLOCKS)
      true
    ) ERR-EMERGENCY-COOLDOWN)
    
    (map-delete pool-contributors {pool-id: pool-id, contributor: tx-sender})
    
    (map-set pools pool-id (merge pool-info {
      total-pool: (- (get total-pool pool-info) contribution-amount)
    }))
    
    (map-set user-balances tx-sender (+ user-balance withdrawal-amount))
    
    (let ((owner-balance (get-user-balance (var-get contract-owner))))
      (map-set user-balances (var-get contract-owner) (+ owner-balance penalty-amount))
    )
    
    (match existing-withdrawal
      existing
        (map-set emergency-withdrawals {pool-id: pool-id, contributor: tx-sender} {
          last-withdrawal: stacks-block-height,
          total-withdrawn: (+ (get total-withdrawn existing) withdrawal-amount),
          penalty-paid: (+ (get penalty-paid existing) penalty-amount)
        })
      (map-set emergency-withdrawals {pool-id: pool-id, contributor: tx-sender} {
        last-withdrawal: stacks-block-height,
        total-withdrawn: withdrawal-amount,
        penalty-paid: penalty-amount
      })
    )
    
    (ok {withdrawn: withdrawal-amount, penalty: penalty-amount})
  )
)