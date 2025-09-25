;; Decentralized Fair Trade Certification Smart Contract
;; This contract manages fair trade certification for products, including verification,
;; certification issuance, renewal, and compliance tracking

;; Contract constants for error handling
(define-constant ERR-UNAUTHORIZED-ACCESS (err u401))
(define-constant ERR-PRODUCT-NOT-FOUND (err u404))
(define-constant ERR-PRODUCT-ALREADY-EXISTS (err u409))
(define-constant ERR-CERTIFICATION-EXPIRED (err u410))
(define-constant ERR-INVALID-PARAMETERS (err u400))
(define-constant ERR-INSUFFICIENT-DOCUMENTATION (err u422))
(define-constant ERR-VERIFICATION-FAILED (err u423))
(define-constant ERR-CERTIFIER-NOT-AUTHORIZED (err u403))
(define-constant ERR-PRODUCT-NOT-CERTIFIED (err u424))
(define-constant ERR-RENEWAL-TOO-EARLY (err u425))
(define-constant ERR-INVALID-CERTIFICATION-LEVEL (err u426))
(define-constant ERR-INVALID-INPUT-LENGTH (err u427))
(define-constant ERR-INVALID-PRINCIPAL (err u428))

;; Contract owner for administrative functions
(define-constant CONTRACT-OWNER tx-sender)

;; Certification status constants
(define-constant CERTIFICATION-PENDING u0)
(define-constant CERTIFICATION-APPROVED u1)
(define-constant CERTIFICATION-REJECTED u2)
(define-constant CERTIFICATION-EXPIRED u3)
(define-constant CERTIFICATION-SUSPENDED u4)

;; Certification levels
(define-constant LEVEL-BASIC u1)
(define-constant LEVEL-PREMIUM u2)
(define-constant LEVEL-GOLD u3)

;; Time constants (in blocks, approximately 10 minutes per block)
(define-constant CERTIFICATION-VALIDITY-PERIOD u52560) ;; ~1 year
(define-constant RENEWAL-WINDOW u5256) ;; ~36 days before expiry

;; Input validation constants
(define-constant MIN-STRING-LENGTH u1)
(define-constant MAX-PRODUCT-ID-LENGTH u64)
(define-constant MAX-PRODUCT-NAME-LENGTH u128)
(define-constant MAX-CATEGORY-LENGTH u64)
(define-constant MAX-COUNTRY-LENGTH u32)
(define-constant MAX-CERTIFIER-NAME-LENGTH u128)
(define-constant MAX-ACCREDITATION-ID-LENGTH u64)
(define-constant MAX-DOCUMENTATION-HASH-LENGTH u128)
(define-constant MAX-VERIFICATION-NOTES-LENGTH u256)
(define-constant MAX-FINDINGS-LENGTH u512)
(define-constant MAX-RECOMMENDATIONS-LENGTH u512)

;; Data structure for product information
(define-map products
  { product-id: (string-ascii 64) }
  {
    producer: principal,
    product-name: (string-ascii 128),
    product-category: (string-ascii 64),
    origin-country: (string-ascii 32),
    created-at: uint,
    updated-at: uint
  }
)

;; Data structure for certification records
(define-map certifications
  { product-id: (string-ascii 64) }
  {
    certification-level: uint,
    status: uint,
    certified-by: principal,
    issued-at: uint,
    expires-at: uint,
    compliance-score: uint,
    documentation-hash: (string-ascii 128),
    verification-notes: (string-ascii 256)
  }
)

;; Data structure for authorized certifiers
(define-map authorized-certifiers
  { certifier: principal }
  {
    name: (string-ascii 128),
    accreditation-id: (string-ascii 64),
    authorized-at: uint,
    active: bool
  }
)

;; Data structure for compliance audits
(define-map compliance-audits
  { audit-id: uint }
  {
    product-id: (string-ascii 64),
    auditor: principal,
    audit-date: uint,
    compliance-score: uint,
    findings: (string-ascii 512),
    recommendations: (string-ascii 512)
  }
)

;; Data structure for certification renewals
(define-map certification-renewals
  { product-id: (string-ascii 64) }
  {
    renewal-requested-at: uint,
    new-documentation-hash: (string-ascii 128),
    renewal-status: uint,
    processed-by: (optional principal),
    processed-at: (optional uint)
  }
)

;; Counter for generating unique audit IDs
(define-data-var audit-counter uint u0)

;; Events for tracking contract activities
(define-data-var last-event-id uint u0)

;; Input validation helper functions
(define-private (validate-string-length (str (string-ascii 512)) (min-len uint) (max-len uint))
  (let ((str-len (len str)))
    (and (>= str-len min-len) (<= str-len max-len))))

(define-private (validate-product-id (product-id (string-ascii 64)))
  (validate-string-length product-id MIN-STRING-LENGTH MAX-PRODUCT-ID-LENGTH))

(define-private (validate-product-name (product-name (string-ascii 128)))
  (validate-string-length product-name MIN-STRING-LENGTH MAX-PRODUCT-NAME-LENGTH))

(define-private (validate-category (category (string-ascii 64)))
  (validate-string-length category MIN-STRING-LENGTH MAX-CATEGORY-LENGTH))

(define-private (validate-country (country (string-ascii 32)))
  (validate-string-length country MIN-STRING-LENGTH MAX-COUNTRY-LENGTH))

(define-private (validate-certifier-name (name (string-ascii 128)))
  (validate-string-length name MIN-STRING-LENGTH MAX-CERTIFIER-NAME-LENGTH))

(define-private (validate-accreditation-id (id (string-ascii 64)))
  (validate-string-length id MIN-STRING-LENGTH MAX-ACCREDITATION-ID-LENGTH))

(define-private (validate-documentation-hash (hash (string-ascii 128)))
  (validate-string-length hash MIN-STRING-LENGTH MAX-DOCUMENTATION-HASH-LENGTH))

(define-private (validate-verification-notes (notes (string-ascii 256)))
  (<= (len notes) MAX-VERIFICATION-NOTES-LENGTH))

(define-private (validate-findings (findings (string-ascii 512)))
  (<= (len findings) MAX-FINDINGS-LENGTH))

(define-private (validate-recommendations (recommendations (string-ascii 512)))
  (<= (len recommendations) MAX-RECOMMENDATIONS-LENGTH))

(define-private (validate-principal (principal-to-check principal))
  (not (is-eq principal-to-check 'SP000000000000000000002Q6VF78)))

;; Helper function to validate certification level
(define-private (is-valid-certification-level (level uint))
  (or (is-eq level LEVEL-BASIC)
      (or (is-eq level LEVEL-PREMIUM)
          (is-eq level LEVEL-GOLD))))

;; Helper function to check if certification is expired
(define-private (is-certification-expired (expires-at uint))
  (> block-height expires-at))

;; Helper function to check if certifier is authorized
(define-private (is-authorized-certifier (certifier principal))
  (match (map-get? authorized-certifiers { certifier: certifier })
    certifier-data (get active certifier-data)
    false))

;; Helper function to generate audit ID
(define-private (generate-audit-id)
  (let ((current-counter (var-get audit-counter)))
    (var-set audit-counter (+ current-counter u1))
    current-counter))

;; Administrative function to authorize a certifier
(define-public (authorize-certifier 
  (certifier principal)
  (name (string-ascii 128))
  (accreditation-id (string-ascii 64)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (validate-principal certifier) ERR-INVALID-PRINCIPAL)
    (asserts! (validate-certifier-name name) ERR-INVALID-INPUT-LENGTH)
    (asserts! (validate-accreditation-id accreditation-id) ERR-INVALID-INPUT-LENGTH)
    (ok (map-set authorized-certifiers
      { certifier: certifier }
      {
        name: name,
        accreditation-id: accreditation-id,
        authorized-at: block-height,
        active: true
      }))))

;; Administrative function to deauthorize a certifier
(define-public (deauthorize-certifier (certifier principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (validate-principal certifier) ERR-INVALID-PRINCIPAL)
    (match (map-get? authorized-certifiers { certifier: certifier })
      certifier-data (ok (map-set authorized-certifiers
        { certifier: certifier }
        (merge certifier-data { active: false })))
      ERR-CERTIFIER-NOT-AUTHORIZED)))

;; Function to register a new product for certification
(define-public (register-product
  (product-id (string-ascii 64))
  (product-name (string-ascii 128))
  (product-category (string-ascii 64))
  (origin-country (string-ascii 32)))
  (begin
    (asserts! (validate-product-id product-id) ERR-INVALID-INPUT-LENGTH)
    (asserts! (validate-product-name product-name) ERR-INVALID-INPUT-LENGTH)
    (asserts! (validate-category product-category) ERR-INVALID-INPUT-LENGTH)
    (asserts! (validate-country origin-country) ERR-INVALID-INPUT-LENGTH)
    (asserts! (is-none (map-get? products { product-id: product-id })) ERR-PRODUCT-ALREADY-EXISTS)
    (ok (map-set products
      { product-id: product-id }
      {
        producer: tx-sender,
        product-name: product-name,
        product-category: product-category,
        origin-country: origin-country,
        created-at: block-height,
        updated-at: block-height
      }))))

;; Function to submit certification application
(define-public (submit-certification-application
  (product-id (string-ascii 64))
  (certification-level uint)
  (documentation-hash (string-ascii 128)))
  (let ((product-data (unwrap! (map-get? products { product-id: product-id }) ERR-PRODUCT-NOT-FOUND)))
    (asserts! (validate-product-id product-id) ERR-INVALID-INPUT-LENGTH)
    (asserts! (is-eq (get producer product-data) tx-sender) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (is-valid-certification-level certification-level) ERR-INVALID-CERTIFICATION-LEVEL)
    (asserts! (validate-documentation-hash documentation-hash) ERR-INVALID-INPUT-LENGTH)
    (ok (map-set certifications
      { product-id: product-id }
      {
        certification-level: certification-level,
        status: CERTIFICATION-PENDING,
        certified-by: CONTRACT-OWNER,
        issued-at: block-height,
        expires-at: u0,
        compliance-score: u0,
        documentation-hash: documentation-hash,
        verification-notes: ""
      }))))

;; Function for authorized certifiers to verify and certify products
(define-public (certify-product
  (product-id (string-ascii 64))
  (approve bool)
  (compliance-score uint)
  (verification-notes (string-ascii 256)))
  (let ((certification-data (unwrap! (map-get? certifications { product-id: product-id }) ERR-PRODUCT-NOT-FOUND)))
    (asserts! (validate-product-id product-id) ERR-INVALID-INPUT-LENGTH)
    (asserts! (validate-verification-notes verification-notes) ERR-INVALID-INPUT-LENGTH)
    (asserts! (is-authorized-certifier tx-sender) ERR-CERTIFIER-NOT-AUTHORIZED)
    (asserts! (is-eq (get status certification-data) CERTIFICATION-PENDING) ERR-VERIFICATION-FAILED)
    (asserts! (<= compliance-score u100) ERR-INVALID-PARAMETERS)
    (let ((new-status (if approve CERTIFICATION-APPROVED CERTIFICATION-REJECTED))
          (expiry-date (if approve (+ block-height CERTIFICATION-VALIDITY-PERIOD) u0)))
      (ok (map-set certifications
        { product-id: product-id }
        (merge certification-data {
          status: new-status,
          certified-by: tx-sender,
          issued-at: block-height,
          expires-at: expiry-date,
          compliance-score: compliance-score,
          verification-notes: verification-notes
        }))))))

;; Function to conduct compliance audit
(define-public (conduct-compliance-audit
  (product-id (string-ascii 64))
  (compliance-score uint)
  (findings (string-ascii 512))
  (recommendations (string-ascii 512)))
  (let ((product-data (unwrap! (map-get? products { product-id: product-id }) ERR-PRODUCT-NOT-FOUND))
        (audit-id (generate-audit-id)))
    (asserts! (validate-product-id product-id) ERR-INVALID-INPUT-LENGTH)
    (asserts! (validate-findings findings) ERR-INVALID-INPUT-LENGTH)
    (asserts! (validate-recommendations recommendations) ERR-INVALID-INPUT-LENGTH)
    (asserts! (is-authorized-certifier tx-sender) ERR-CERTIFIER-NOT-AUTHORIZED)
    (asserts! (<= compliance-score u100) ERR-INVALID-PARAMETERS)
    (begin
      (map-set compliance-audits
        { audit-id: audit-id }
        {
          product-id: product-id,
          auditor: tx-sender,
          audit-date: block-height,
          compliance-score: compliance-score,
          findings: findings,
          recommendations: recommendations
        })
      (match (map-get? certifications { product-id: product-id })
        cert-data (map-set certifications
          { product-id: product-id }
          (merge cert-data { compliance-score: compliance-score }))
        true)
      (ok audit-id))))

;; Function to request certification renewal
(define-public (request-certification-renewal
  (product-id (string-ascii 64))
  (new-documentation-hash (string-ascii 128)))
  (let ((product-data (unwrap! (map-get? products { product-id: product-id }) ERR-PRODUCT-NOT-FOUND))
        (cert-data (unwrap! (map-get? certifications { product-id: product-id }) ERR-PRODUCT-NOT-CERTIFIED)))
    (asserts! (validate-product-id product-id) ERR-INVALID-INPUT-LENGTH)
    (asserts! (validate-documentation-hash new-documentation-hash) ERR-INVALID-INPUT-LENGTH)
    (asserts! (is-eq (get producer product-data) tx-sender) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (is-eq (get status cert-data) CERTIFICATION-APPROVED) ERR-PRODUCT-NOT-CERTIFIED)
    (asserts! (<= (- (get expires-at cert-data) block-height) RENEWAL-WINDOW) ERR-RENEWAL-TOO-EARLY)
    (ok (map-set certification-renewals
      { product-id: product-id }
      {
        renewal-requested-at: block-height,
        new-documentation-hash: new-documentation-hash,
        renewal-status: CERTIFICATION-PENDING,
        processed-by: none,
        processed-at: none
      }))))

;; Function to process certification renewal
(define-public (process-certification-renewal
  (product-id (string-ascii 64))
  (approve bool)
  (new-compliance-score uint))
  (let ((renewal-data (unwrap! (map-get? certification-renewals { product-id: product-id }) ERR-PRODUCT-NOT-FOUND))
        (cert-data (unwrap! (map-get? certifications { product-id: product-id }) ERR-PRODUCT-NOT-CERTIFIED)))
    (asserts! (validate-product-id product-id) ERR-INVALID-INPUT-LENGTH)
    (asserts! (is-authorized-certifier tx-sender) ERR-CERTIFIER-NOT-AUTHORIZED)
    (asserts! (is-eq (get renewal-status renewal-data) CERTIFICATION-PENDING) ERR-VERIFICATION-FAILED)
    (asserts! (<= new-compliance-score u100) ERR-INVALID-PARAMETERS)
    (begin
      (map-set certification-renewals
        { product-id: product-id }
        (merge renewal-data {
          renewal-status: (if approve CERTIFICATION-APPROVED CERTIFICATION-REJECTED),
          processed-by: (some tx-sender),
          processed-at: (some block-height)
        }))
      (if approve
        (map-set certifications
          { product-id: product-id }
          (merge cert-data {
            issued-at: block-height,
            expires-at: (+ block-height CERTIFICATION-VALIDITY-PERIOD),
            compliance-score: new-compliance-score,
            documentation-hash: (get new-documentation-hash renewal-data)
          }))
        true)
      (ok approve))))

;; Function to suspend certification
(define-public (suspend-certification (product-id (string-ascii 64)))
  (let ((cert-data (unwrap! (map-get? certifications { product-id: product-id }) ERR-PRODUCT-NOT-CERTIFIED)))
    (asserts! (validate-product-id product-id) ERR-INVALID-INPUT-LENGTH)
    (asserts! (is-authorized-certifier tx-sender) ERR-CERTIFIER-NOT-AUTHORIZED)
    (asserts! (is-eq (get status cert-data) CERTIFICATION-APPROVED) ERR-PRODUCT-NOT-CERTIFIED)
    (ok (map-set certifications
      { product-id: product-id }
      (merge cert-data { status: CERTIFICATION-SUSPENDED })))))

;; Function to reinstate suspended certification
(define-public (reinstate-certification (product-id (string-ascii 64)))
  (let ((cert-data (unwrap! (map-get? certifications { product-id: product-id }) ERR-PRODUCT-NOT-CERTIFIED)))
    (asserts! (validate-product-id product-id) ERR-INVALID-INPUT-LENGTH)
    (asserts! (is-authorized-certifier tx-sender) ERR-CERTIFIER-NOT-AUTHORIZED)
    (asserts! (is-eq (get status cert-data) CERTIFICATION-SUSPENDED) ERR-VERIFICATION-FAILED)
    (asserts! (not (is-certification-expired (get expires-at cert-data))) ERR-CERTIFICATION-EXPIRED)
    (ok (map-set certifications
      { product-id: product-id }
      (merge cert-data { status: CERTIFICATION-APPROVED })))))

;; Read-only function to get product information
(define-read-only (get-product (product-id (string-ascii 64)))
  (if (validate-product-id product-id)
    (map-get? products { product-id: product-id })
    none))

;; Read-only function to get certification status
(define-read-only (get-certification (product-id (string-ascii 64)))
  (if (validate-product-id product-id)
    (map-get? certifications { product-id: product-id })
    none))

;; Read-only function to check if product is currently certified
(define-read-only (is-product-certified (product-id (string-ascii 64)))
  (if (validate-product-id product-id)
    (match (map-get? certifications { product-id: product-id })
      cert-data (and 
        (is-eq (get status cert-data) CERTIFICATION-APPROVED)
        (not (is-certification-expired (get expires-at cert-data))))
      false)
    false))

;; Read-only function to get certifier information
(define-read-only (get-certifier (certifier principal))
  (if (validate-principal certifier)
    (map-get? authorized-certifiers { certifier: certifier })
    none))

;; Read-only function to get compliance audit
(define-read-only (get-compliance-audit (audit-id uint))
  (map-get? compliance-audits { audit-id: audit-id }))

;; Read-only function to get certification renewal status
(define-read-only (get-certification-renewal (product-id (string-ascii 64)))
  (if (validate-product-id product-id)
    (map-get? certification-renewals { product-id: product-id })
    none))

;; Read-only function to verify certification authenticity
(define-read-only (verify-certification-authenticity 
  (product-id (string-ascii 64))
  (expected-hash (string-ascii 128)))
  (if (and (validate-product-id product-id) (validate-documentation-hash expected-hash))
    (match (map-get? certifications { product-id: product-id })
      cert-data (and
        (is-eq (get status cert-data) CERTIFICATION-APPROVED)
        (not (is-certification-expired (get expires-at cert-data)))
        (is-eq (get documentation-hash cert-data) expected-hash))
      false)
    false))

;; Read-only function to get certification expiry status
(define-read-only (get-certification-expiry-info (product-id (string-ascii 64)))
  (if (validate-product-id product-id)
    (match (map-get? certifications { product-id: product-id })
      cert-data (let ((expires-at (get expires-at cert-data))
                       (blocks-until-expiry (if (> expires-at block-height) 
                                             (- expires-at block-height) 
                                             u0)))
        (some {
          expires-at: expires-at,
          blocks-until-expiry: blocks-until-expiry,
          is-expired: (is-certification-expired expires-at),
          renewal-window-open: (<= blocks-until-expiry RENEWAL-WINDOW)
        }))
      none)
    none))

;; Read-only function to get contract statistics
(define-read-only (get-contract-stats)
  {
    current-block: block-height,
    total-audits: (var-get audit-counter),
    certification-validity-period: CERTIFICATION-VALIDITY-PERIOD,
    renewal-window: RENEWAL-WINDOW
  })