;; Time Bank Smart Contract
;; A comprehensive contract for exchanging time credits and services on-chain

;; Data maps
(define-map time-balances principal uint)
(define-map user-profiles principal {
  name: (string-ascii 50),
  skills: (list 10 (string-ascii 30)),
  rating: uint,
  total-ratings: uint
})
(define-map service-offers principal {
  category: (string-ascii 30),
  description: (string-ascii 200),
  rate-per-hour: uint,
  available: bool
})
(define-map escrow-agreements uint {
  provider: principal,
  client: principal,
  amount: uint,
  service-description: (string-ascii 200),
  status: (string-ascii 20),
  created-at: uint
})
(define-map transaction-history uint {
  from: principal,
  to: principal,
  amount: uint,
  tx-type: (string-ascii 20),
  timestamp: uint,
  description: (string-ascii 100)
})

;; Data variables
(define-data-var total-time-supply uint u0)
(define-data-var next-escrow-id uint u1)
(define-data-var next-transaction-id uint u1)
(define-data-var contract-owner principal tx-sender)

;; Error constants
(define-constant ERR-INSUFFICIENT-BALANCE (err u100))
(define-constant ERR-INVALID-AMOUNT (err u101))
(define-constant ERR-SAME-PRINCIPAL (err u102))
(define-constant ERR-NOT-FOUND (err u103))
(define-constant ERR-UNAUTHORIZED (err u104))
(define-constant ERR-INVALID-STATUS (err u105))
(define-constant ERR-PROFILE-EXISTS (err u106))
(define-constant ERR-INVALID-RATING (err u107))

;; Deposit time credits
(define-public (deposit-time (amount uint))
  (let ((current-balance (default-to u0 (map-get? time-balances tx-sender))))
    (if (> amount u0)
      (begin
        (map-set time-balances tx-sender (+ current-balance amount))
        (var-set total-time-supply (+ (var-get total-time-supply) amount))
        (ok amount))
      ERR-INVALID-AMOUNT)))

;; Withdraw time credits
(define-public (withdraw-time (amount uint))
  (let ((current-balance (default-to u0 (map-get? time-balances tx-sender))))
    (if (and (> amount u0) (>= current-balance amount))
      (begin
        (map-set time-balances tx-sender (- current-balance amount))
        (var-set total-time-supply (- (var-get total-time-supply) amount))
        (ok amount))
      (if (is-eq amount u0)
        ERR-INVALID-AMOUNT
        ERR-INSUFFICIENT-BALANCE))))

;; Transfer time credits between users
(define-public (transfer-time (recipient principal) (amount uint))
  (let ((sender-balance (default-to u0 (map-get? time-balances tx-sender)))
        (recipient-balance (default-to u0 (map-get? time-balances recipient))))
    (if (is-eq tx-sender recipient)
      ERR-SAME-PRINCIPAL
      (if (and (> amount u0) (>= sender-balance amount))
        (begin
          (map-set time-balances tx-sender (- sender-balance amount))
          (map-set time-balances recipient (+ recipient-balance amount))
          (ok amount))
        (if (is-eq amount u0)
          ERR-INVALID-AMOUNT
          ERR-INSUFFICIENT-BALANCE)))))

;; Read-only functions
(define-read-only (get-balance (account principal))
  (default-to u0 (map-get? time-balances account)))

(define-read-only (get-total-supply)
  (var-get total-time-supply))

(define-read-only (get-my-balance)
  (get-balance tx-sender))

;; User profile management
(define-public (create-profile (name (string-ascii 50)) (skills (list 10 (string-ascii 30))))
  (if (is-some (map-get? user-profiles tx-sender))
    ERR-PROFILE-EXISTS
    (begin
      (map-set user-profiles tx-sender {
        name: name,
        skills: skills,
        rating: u0,
        total-ratings: u0
      })
      (ok true))))

(define-public (update-skills (new-skills (list 10 (string-ascii 30))))
  (match (map-get? user-profiles tx-sender)
    profile (begin
      (map-set user-profiles tx-sender (merge profile { skills: new-skills }))
      (ok true))
    ERR-NOT-FOUND))

;; Service marketplace
(define-public (create-service-offer (category (string-ascii 30)) (description (string-ascii 200)) (rate uint))
  (begin
    (map-set service-offers tx-sender {
      category: category,
      description: description,
      rate-per-hour: rate,
      available: true
    })
    (ok true)))

(define-public (toggle-service-availability)
  (match (map-get? service-offers tx-sender)
    offer (begin
      (map-set service-offers tx-sender (merge offer { available: (not (get available offer)) }))
      (ok true))
    ERR-NOT-FOUND))

;; Time escrow system
(define-public (create-escrow (provider principal) (amount uint) (service-desc (string-ascii 200)))
  (let ((escrow-id (var-get next-escrow-id))
        (client-balance (default-to u0 (map-get? time-balances tx-sender))))
    (if (and (> amount u0) (>= client-balance amount) (not (is-eq tx-sender provider)))
      (begin
        (map-set time-balances tx-sender (- client-balance amount))
        (map-set escrow-agreements escrow-id {
          provider: provider,
          client: tx-sender,
          amount: amount,
          service-description: service-desc,
          status: "pending",
          created-at: block-height
        })
        (var-set next-escrow-id (+ escrow-id u1))
        (log-transaction tx-sender provider amount "escrow-created" "Service escrow created")
        (ok escrow-id))
      (if (is-eq tx-sender provider)
        ERR-SAME-PRINCIPAL
        (if (is-eq amount u0)
          ERR-INVALID-AMOUNT
          ERR-INSUFFICIENT-BALANCE)))))

(define-public (complete-escrow (escrow-id uint))
  (match (map-get? escrow-agreements escrow-id)
    agreement
      (if (is-eq tx-sender (get provider agreement))
        (if (is-eq (get status agreement) "pending")
          (let ((provider-balance (default-to u0 (map-get? time-balances (get provider agreement)))))
            (begin
              (map-set time-balances (get provider agreement) (+ provider-balance (get amount agreement)))
              (map-set escrow-agreements escrow-id (merge agreement { status: "completed" }))
              (log-transaction (get client agreement) (get provider agreement) (get amount agreement) "service-completed" "Service completed")
              (ok true)))
          ERR-INVALID-STATUS)
        ERR-UNAUTHORIZED)
    ERR-NOT-FOUND))

(define-public (cancel-escrow (escrow-id uint))
  (match (map-get? escrow-agreements escrow-id)
    agreement
      (if (is-eq tx-sender (get client agreement))
        (if (is-eq (get status agreement) "pending")
          (let ((client-balance (default-to u0 (map-get? time-balances (get client agreement)))))
            (begin
              (map-set time-balances (get client agreement) (+ client-balance (get amount agreement)))
              (map-set escrow-agreements escrow-id (merge agreement { status: "cancelled" }))
              (log-transaction (get client agreement) (get provider agreement) (get amount agreement) "escrow-cancelled" "")
              (ok true)))
          ERR-INVALID-STATUS)
        ERR-UNAUTHORIZED)
    ERR-NOT-FOUND))

;; Rating system
(define-public (rate-user (user principal) (rating uint))
  (if (and (>= rating u1) (<= rating u5))
    (match (map-get? user-profiles user)
      profile
        (let ((current-rating (get rating profile))
              (total-ratings (get total-ratings profile))
              (new-total-ratings (+ total-ratings u1))
              (new-average-rating (/ (+ (* current-rating total-ratings) rating) new-total-ratings)))
          (begin
            (map-set user-profiles user (merge profile {
              rating: new-average-rating,
              total-ratings: new-total-ratings
            }))
            (ok new-average-rating)))
      ERR-NOT-FOUND)
    ERR-INVALID-RATING))

;; Transaction logging helper
(define-private (log-transaction (from principal) (to principal) (amount uint) (tx-type (string-ascii 20)) (description (string-ascii 100)))
  (let ((tx-id (var-get next-transaction-id)))
    (begin
      (map-set transaction-history tx-id {
        from: from,
        to: to,
        amount: amount,
        tx-type: tx-type,
        timestamp: block-height,
        description: description
      })
      (var-set next-transaction-id (+ tx-id u1))
      tx-id)))

;; Enhanced transfer with logging
(define-public (transfer-time-logged (recipient principal) (amount uint) (description (string-ascii 100)))
  (let ((sender-balance (default-to u0 (map-get? time-balances tx-sender)))
        (recipient-balance (default-to u0 (map-get? time-balances recipient))))
    (if (is-eq tx-sender recipient)
      ERR-SAME-PRINCIPAL
      (if (and (> amount u0) (>= sender-balance amount))
        (begin
          (map-set time-balances tx-sender (- sender-balance amount))
          (map-set time-balances recipient (+ recipient-balance amount))
          (log-transaction tx-sender recipient amount "transfer" description)
          (ok amount))
        (if (is-eq amount u0)
          ERR-INVALID-AMOUNT
          ERR-INSUFFICIENT-BALANCE)))))

;; Admin functions
(define-public (set-contract-owner (new-owner principal))
  (if (is-eq tx-sender (var-get contract-owner))
    (begin
      (var-set contract-owner new-owner)
      (ok true))
    ERR-UNAUTHORIZED))

(define-public (emergency-freeze-user (user principal))
  (if (is-eq tx-sender (var-get contract-owner))
    (begin
      (map-set time-balances user u0)
      (ok true))
    ERR-UNAUTHORIZED))

;; Enhanced read-only functions
(define-read-only (get-user-profile (user principal))
  (map-get? user-profiles user))

(define-read-only (get-service-offer (provider principal))
  (map-get? service-offers provider))

(define-read-only (get-escrow-details (escrow-id uint))
  (map-get? escrow-agreements escrow-id))

(define-read-only (get-transaction (tx-id uint))
  (map-get? transaction-history tx-id))

(define-read-only (get-contract-owner)
  (var-get contract-owner))

(define-read-only (get-user-rating (user principal))
  (match (map-get? user-profiles user)
    profile (some (get rating profile))
    none))

(define-read-only (get-next-escrow-id)
  (var-get next-escrow-id))

(define-read-only (get-next-transaction-id)
  (var-get next-transaction-id))