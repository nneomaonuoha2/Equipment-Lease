;; Equipment Lease Tokenization Smart Contract
;; This contract enables tokenization of equipment for leasing purposes

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-UNAUTHORIZED (err u100))
(define-constant ERR-NOT-FOUND (err u101))
(define-constant ERR-ALREADY-EXISTS (err u102))
(define-constant ERR-INSUFFICIENT-BALANCE (err u103))
(define-constant ERR-LEASE-ACTIVE (err u104))
(define-constant ERR-LEASE-EXPIRED (err u105))
(define-constant ERR-INVALID-AMOUNT (err u106))
(define-constant ERR-INVALID-DURATION (err u107))
(define-constant ERR-PAYMENT-OVERDUE (err u108))
(define-constant ERR-EQUIPMENT-NOT-AVAILABLE (err u109))
(define-constant ERR-INVALID-EQUIPMENT-STATE (err u110))
(define-constant ERR-INVALID-INPUT (err u111))

;; Data Variables
(define-data-var next-equipment-id uint u1)
(define-data-var next-lease-id uint u1)
(define-data-var platform-fee-rate uint u250) ;; 2.5% in basis points
(define-data-var max-lease-duration uint u31536000) ;; 1 year in seconds

;; Equipment Status Enum
(define-constant EQUIPMENT-STATUS-AVAILABLE u0)
(define-constant EQUIPMENT-STATUS-LEASED u1)
(define-constant EQUIPMENT-STATUS-MAINTENANCE u2)
(define-constant EQUIPMENT-STATUS-RETIRED u3)

;; Lease Status Enum
(define-constant LEASE-STATUS-ACTIVE u0)
(define-constant LEASE-STATUS-COMPLETED u1)
(define-constant LEASE-STATUS-TERMINATED u2)
(define-constant LEASE-STATUS-DEFAULTED u3)

;; Data Maps
(define-map equipment-registry
  { equipment-id: uint }
  {
    owner: principal,
    name: (string-ascii 100),
    description: (string-ascii 500),
    category: (string-ascii 50),
    daily-rate: uint,
    deposit-required: uint,
    status: uint,
    created-at: uint,
    total-earnings: uint,
    maintenance-cost: uint
  }
)

(define-map lease-agreements
  { lease-id: uint }
  {
    equipment-id: uint,
    lessee: principal,
    lessor: principal,
    start-time: uint,
    end-time: uint,
    daily-rate: uint,
    total-amount: uint,
    deposit-paid: uint,
    status: uint,
    payments-made: uint,
    last-payment-time: uint
  }
)

(define-map equipment-tokens
  { equipment-id: uint, holder: principal }
  { balance: uint }
)

(define-map equipment-token-supply
  { equipment-id: uint }
  { total-supply: uint }
)

(define-map lease-payments
  { lease-id: uint, payment-id: uint }
  {
    amount: uint,
    payment-date: uint,
    due-date: uint,
    status: uint ;; 0: pending, 1: paid, 2: overdue
  }
)

(define-map user-balances
  { user: principal }
  { balance: uint }
)

(define-map equipment-ratings
  { equipment-id: uint }
  {
    total-rating: uint,
    rating-count: uint,
    average-rating: uint
  }
)

;; Authorization map for contract operators
(define-map authorized-operators
  { operator: principal }
  { authorized: bool }
)

;; Read-only functions

(define-read-only (get-equipment-info (equipment-id uint))
  (map-get? equipment-registry { equipment-id: equipment-id })
)

(define-read-only (get-lease-info (lease-id uint))
  (map-get? lease-agreements { lease-id: lease-id })
)

(define-read-only (get-equipment-token-balance (equipment-id uint) (holder principal))
  (default-to u0 (get balance (map-get? equipment-tokens { equipment-id: equipment-id, holder: holder })))
)

(define-read-only (get-equipment-token-supply (equipment-id uint))
  (default-to u0 (get total-supply (map-get? equipment-token-supply { equipment-id: equipment-id })))
)

(define-read-only (get-user-balance (user principal))
  (default-to u0 (get balance (map-get? user-balances { user: user })))
)

(define-read-only (get-equipment-rating (equipment-id uint))
  (map-get? equipment-ratings { equipment-id: equipment-id })
)

(define-read-only (get-platform-fee-rate)
  (var-get platform-fee-rate)
)

(define-read-only (calculate-lease-cost (daily-rate uint) (duration uint))
  (let ((days (/ duration u86400))) ;; Convert seconds to days
    (* daily-rate days)
  )
)

(define-read-only (is-lease-overdue (lease-id uint))
  (match (get-lease-info lease-id)
    lease-data 
    (let ((current-time (unwrap-panic (get-block-info? time (- block-height u1)))))
      (and 
        (is-eq (get status lease-data) LEASE-STATUS-ACTIVE)
        (> current-time (get end-time lease-data))
      )
    )
    false
  )
)

(define-read-only (get-available-equipment)
  ;; This would require iteration in a real implementation
  ;; For now, returns true if equipment exists and is available
  true
)

;; Private functions

(define-private (is-authorized (user principal))
  (or 
    (is-eq user CONTRACT-OWNER)
    (default-to false (get authorized (map-get? authorized-operators { operator: user })))
  )
)

(define-private (calculate-platform-fee (amount uint))
  (/ (* amount (var-get platform-fee-rate)) u10000)
)

(define-private (transfer-funds (from principal) (to principal) (amount uint))
  (let ((from-balance (get-user-balance from)))
    (if (and (>= from-balance amount) (> amount u0))
      (begin
        (map-set user-balances 
          { user: from } 
          { balance: (- from-balance amount) })
        (map-set user-balances 
          { user: to } 
          { balance: (+ (get-user-balance to) amount) })
        (ok true)
      )
      ERR-INSUFFICIENT-BALANCE
    )
  )
)

(define-private (mint-equipment-tokens (equipment-id uint) (recipient principal) (amount uint))
  (if (> amount u0)
    (let (
      (current-balance (get-equipment-token-balance equipment-id recipient))
      (current-supply (get-equipment-token-supply equipment-id))
    )
      (map-set equipment-tokens
        { equipment-id: equipment-id, holder: recipient }
        { balance: (+ current-balance amount) })
      (map-set equipment-token-supply
        { equipment-id: equipment-id }
        { total-supply: (+ current-supply amount) })
      (ok true)
    )
    ERR-INVALID-AMOUNT
  )
)

(define-private (burn-equipment-tokens (equipment-id uint) (holder principal) (amount uint))
  (let (
    (current-balance (get-equipment-token-balance equipment-id holder))
    (current-supply (get-equipment-token-supply equipment-id))
  )
    (if (and (>= current-balance amount) (> amount u0))
      (begin
        (map-set equipment-tokens
          { equipment-id: equipment-id, holder: holder }
          { balance: (- current-balance amount) })
        (map-set equipment-token-supply
          { equipment-id: equipment-id }
          { total-supply: (- current-supply amount) })
        (ok true)
      )
      ERR-INSUFFICIENT-BALANCE
    )
  )
)

;; Input validation functions
(define-private (validate-string-input (input (string-ascii 500)))
  (and (> (len input) u0) (<= (len input) u500))
)

(define-private (validate-category-input (input (string-ascii 50)))
  (and (> (len input) u0) (<= (len input) u50))
)

(define-private (validate-name-input (input (string-ascii 100)))
  (and (> (len input) u0) (<= (len input) u100))
)

(define-private (validate-equipment-status (status uint))
  (or (is-eq status EQUIPMENT-STATUS-AVAILABLE)
      (is-eq status EQUIPMENT-STATUS-LEASED)
      (is-eq status EQUIPMENT-STATUS-MAINTENANCE)
      (is-eq status EQUIPMENT-STATUS-RETIRED))
)

(define-private (validate-rating (rating uint))
  (and (>= rating u1) (<= rating u5))
)

;; Public functions

(define-public (register-equipment 
  (name (string-ascii 100))
  (description (string-ascii 500))
  (category (string-ascii 50))
  (daily-rate uint)
  (deposit-required uint)
  (token-supply uint))
  (let ((equipment-id (var-get next-equipment-id))
        (current-time (unwrap-panic (get-block-info? time (- block-height u1)))))
    ;; Input validation
    (asserts! (validate-name-input name) ERR-INVALID-INPUT)
    (asserts! (validate-string-input description) ERR-INVALID-INPUT)
    (asserts! (validate-category-input category) ERR-INVALID-INPUT)
    (asserts! (> daily-rate u0) ERR-INVALID-AMOUNT)
    (asserts! (>= deposit-required u0) ERR-INVALID-INPUT)
    (asserts! (> token-supply u0) ERR-INVALID-AMOUNT)
    
    (begin
      (map-set equipment-registry
        { equipment-id: equipment-id }
        {
          owner: tx-sender,
          name: name,
          description: description,
          category: category,
          daily-rate: daily-rate,
          deposit-required: deposit-required,
          status: EQUIPMENT-STATUS-AVAILABLE,
          created-at: current-time,
          total-earnings: u0,
          maintenance-cost: u0
        })
      (unwrap! (mint-equipment-tokens equipment-id tx-sender token-supply) ERR-INVALID-AMOUNT)
      (var-set next-equipment-id (+ equipment-id u1))
      (ok equipment-id)
    )
  )
)

(define-public (create-lease 
  (equipment-id uint)
  (duration uint))
  (let (
    (equipment-data (unwrap! (get-equipment-info equipment-id) ERR-NOT-FOUND))
    (lease-id (var-get next-lease-id))
    (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
    (end-time (+ current-time duration))
    (total-cost (calculate-lease-cost (get daily-rate equipment-data) duration))
    (required-deposit (get deposit-required equipment-data))
    (total-required (+ total-cost required-deposit))
  )
    ;; Input validation
    (asserts! (is-eq (get status equipment-data) EQUIPMENT-STATUS-AVAILABLE) ERR-EQUIPMENT-NOT-AVAILABLE)
    (asserts! (<= duration (var-get max-lease-duration)) ERR-INVALID-DURATION)
    (asserts! (> duration u0) ERR-INVALID-DURATION)
    (asserts! (>= (get-user-balance tx-sender) total-required) ERR-INSUFFICIENT-BALANCE)
    
    (begin
      ;; Transfer funds for lease
      (unwrap! (transfer-funds tx-sender (get owner equipment-data) total-cost) ERR-INSUFFICIENT-BALANCE)
      ;; Hold deposit
      (unwrap! (transfer-funds tx-sender (as-contract tx-sender) required-deposit) ERR-INSUFFICIENT-BALANCE)
      
      ;; Update equipment status
      (map-set equipment-registry
        { equipment-id: equipment-id }
        (merge equipment-data { status: EQUIPMENT-STATUS-LEASED }))
      
      ;; Create lease agreement
      (map-set lease-agreements
        { lease-id: lease-id }
        {
          equipment-id: equipment-id,
          lessee: tx-sender,
          lessor: (get owner equipment-data),
          start-time: current-time,
          end-time: end-time,
          daily-rate: (get daily-rate equipment-data),
          total-amount: total-cost,
          deposit-paid: required-deposit,
          status: LEASE-STATUS-ACTIVE,
          payments-made: total-cost,
          last-payment-time: current-time
        })
      
      (var-set next-lease-id (+ lease-id u1))
      (ok lease-id)
    )
  )
)

(define-public (complete-lease (lease-id uint))
  (let (
    (lease-data (unwrap! (get-lease-info lease-id) ERR-NOT-FOUND))
    (equipment-data (unwrap! (get-equipment-info (get equipment-id lease-data)) ERR-NOT-FOUND))
    (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
  )
    (asserts! (is-eq (get lessee lease-data) tx-sender) ERR-UNAUTHORIZED)
    (asserts! (is-eq (get status lease-data) LEASE-STATUS-ACTIVE) ERR-INVALID-EQUIPMENT-STATE)
    
    (begin
      ;; Return deposit to lessee
      (unwrap! (transfer-funds (as-contract tx-sender) tx-sender (get deposit-paid lease-data)) ERR-INSUFFICIENT-BALANCE)
      
      ;; Update lease status
      (map-set lease-agreements
        { lease-id: lease-id }
        (merge lease-data { status: LEASE-STATUS-COMPLETED }))
      
      ;; Update equipment status back to available
      (map-set equipment-registry
        { equipment-id: (get equipment-id lease-data) }
        (merge equipment-data { 
          status: EQUIPMENT-STATUS-AVAILABLE,
          total-earnings: (+ (get total-earnings equipment-data) (get total-amount lease-data))
        }))
      
      (ok true)
    )
  )
)

(define-public (terminate-lease (lease-id uint))
  (let (
    (lease-data (unwrap! (get-lease-info lease-id) ERR-NOT-FOUND))
    (equipment-data (unwrap! (get-equipment-info (get equipment-id lease-data)) ERR-NOT-FOUND))
  )
    (asserts! (or 
      (is-eq (get lessee lease-data) tx-sender)
      (is-eq (get lessor lease-data) tx-sender)
      (is-authorized tx-sender)) ERR-UNAUTHORIZED)
    
    (begin
      ;; Calculate penalty (keep portion of deposit)
      (let ((penalty (/ (get deposit-paid lease-data) u2))) ;; 50% penalty
        (unwrap! (transfer-funds (as-contract tx-sender) (get lessor lease-data) penalty) ERR-INSUFFICIENT-BALANCE)
        (unwrap! (transfer-funds (as-contract tx-sender) (get lessee lease-data) (- (get deposit-paid lease-data) penalty)) ERR-INSUFFICIENT-BALANCE)
      )
      
      ;; Update lease status
      (map-set lease-agreements
        { lease-id: lease-id }
        (merge lease-data { status: LEASE-STATUS-TERMINATED }))
      
      ;; Update equipment status back to available
      (map-set equipment-registry
        { equipment-id: (get equipment-id lease-data) }
        (merge equipment-data { status: EQUIPMENT-STATUS-AVAILABLE }))
      
      (ok true)
    )
  )
)

(define-public (transfer-equipment-tokens 
  (equipment-id uint)
  (recipient principal)
  (amount uint))
  (let ((sender-balance (get-equipment-token-balance equipment-id tx-sender)))
    ;; Input validation
    (asserts! (is-some (get-equipment-info equipment-id)) ERR-NOT-FOUND)
    (asserts! (>= sender-balance amount) ERR-INSUFFICIENT-BALANCE)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    ;; Validate recipient is not the zero principal
    (asserts! (not (is-eq recipient 'SP000000000000000000002Q6VF78)) ERR-INVALID-INPUT)
    
    (begin
      (unwrap! (burn-equipment-tokens equipment-id tx-sender amount) ERR-INSUFFICIENT-BALANCE)
      (unwrap! (mint-equipment-tokens equipment-id recipient amount) ERR-INVALID-AMOUNT)
      (ok true)
    )
  )
)

(define-public (rate-equipment (equipment-id uint) (rating uint))
  (let (
    (equipment-data (unwrap! (get-equipment-info equipment-id) ERR-NOT-FOUND))
    (current-rating (default-to 
      { total-rating: u0, rating-count: u0, average-rating: u0 }
      (get-equipment-rating equipment-id)))
  )
    ;; Input validation
    (asserts! (validate-rating rating) ERR-INVALID-AMOUNT)
    ;; Additional validation to ensure equipment-id is valid
    (asserts! (> equipment-id u0) ERR-INVALID-INPUT)
    
    (let (
      (validated-total (+ (get total-rating current-rating) rating))
      (validated-count (+ (get rating-count current-rating) u1))
      (validated-average (/ validated-total validated-count))
    )
      (map-set equipment-ratings
        { equipment-id: equipment-id }
        {
          total-rating: validated-total,
          rating-count: validated-count,
          average-rating: validated-average
        })
      (ok true)
    )
  )
)

(define-public (deposit-funds (amount uint))
  (begin
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (match (stx-transfer? amount tx-sender (as-contract tx-sender))
      success (begin
        (map-set user-balances 
          { user: tx-sender } 
          { balance: (+ (get-user-balance tx-sender) amount) })
        (ok true))
      error ERR-INSUFFICIENT-BALANCE)
  )
)

(define-public (withdraw-funds (amount uint))
  (let ((user-balance (get-user-balance tx-sender))
        (caller tx-sender))
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (asserts! (>= user-balance amount) ERR-INSUFFICIENT-BALANCE)
    
    (match (as-contract (stx-transfer? amount tx-sender caller))
      success (begin
        (map-set user-balances 
          { user: caller } 
          { balance: (- user-balance amount) })
        (ok true))
      error ERR-INSUFFICIENT-BALANCE)
  )
)

(define-public (update-equipment-status (equipment-id uint) (new-status uint))
  (let ((equipment-data (unwrap! (get-equipment-info equipment-id) ERR-NOT-FOUND)))
    (asserts! (is-eq (get owner equipment-data) tx-sender) ERR-UNAUTHORIZED)
    (asserts! (validate-equipment-status new-status) ERR-INVALID-INPUT)
    
    (begin
      (map-set equipment-registry
        { equipment-id: equipment-id }
        (merge equipment-data { status: new-status }))
      (ok true)
    )
  )
)

(define-public (add-authorized-operator (operator principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    ;; Validate operator is not the zero principal
    (asserts! (not (is-eq operator 'SP000000000000000000002Q6VF78)) ERR-INVALID-INPUT)
    (map-set authorized-operators 
      { operator: operator } 
      { authorized: true })
    (ok true)
  )
)

(define-public (remove-authorized-operator (operator principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    ;; Validate operator is not the zero principal
    (asserts! (not (is-eq operator 'SP000000000000000000002Q6VF78)) ERR-INVALID-INPUT)
    (map-set authorized-operators 
      { operator: operator } 
      { authorized: false })
    (ok true)
  )
)

(define-public (update-platform-fee-rate (new-rate uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    (asserts! (<= new-rate u1000) ERR-INVALID-AMOUNT)
    (var-set platform-fee-rate new-rate)
    (ok true)
  )
)

(define-public (emergency-pause-equipment (equipment-id uint))
  (let ((equipment-data (unwrap! (get-equipment-info equipment-id) ERR-NOT-FOUND)))
    (asserts! (or (is-eq (get owner equipment-data) tx-sender) (is-authorized tx-sender)) ERR-UNAUTHORIZED)
    (map-set equipment-registry
      { equipment-id: equipment-id }
      (merge equipment-data { status: EQUIPMENT-STATUS-MAINTENANCE }))
    (ok true)
  )
)