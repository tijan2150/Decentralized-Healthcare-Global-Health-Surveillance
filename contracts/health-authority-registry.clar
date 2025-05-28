;; Health Authority Registry Contract
;; Manages verification and registration of international health organizations

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_ALREADY_REGISTERED (err u101))
(define-constant ERR_NOT_FOUND (err u102))
(define-constant ERR_INVALID_STATUS (err u103))

;; Data Variables
(define-data-var next-authority-id uint u1)

;; Data Maps
(define-map health-authorities
  { authority-id: uint }
  {
    name: (string-ascii 100),
    country: (string-ascii 50),
    organization-type: (string-ascii 50),
    verification-status: (string-ascii 20),
    registered-by: principal,
    registration-date: uint,
    last-updated: uint
  }
)

(define-map authority-principals
  { principal: principal }
  { authority-id: uint }
)

(define-map verified-authorities
  { authority-id: uint }
  { verified: bool }
)

;; Public Functions

;; Register a new health authority
(define-public (register-authority (name (string-ascii 100))
                                 (country (string-ascii 50))
                                 (organization-type (string-ascii 50)))
  (let ((authority-id (var-get next-authority-id)))
    (asserts! (is-none (map-get? authority-principals { principal: tx-sender })) ERR_ALREADY_REGISTERED)

    (map-set health-authorities
      { authority-id: authority-id }
      {
        name: name,
        country: country,
        organization-type: organization-type,
        verification-status: "pending",
        registered-by: tx-sender,
        registration-date: block-height,
        last-updated: block-height
      }
    )

    (map-set authority-principals
      { principal: tx-sender }
      { authority-id: authority-id }
    )

    (var-set next-authority-id (+ authority-id u1))
    (ok authority-id)
  )
)

;; Verify a health authority (only contract owner)
(define-public (verify-authority (authority-id uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (is-some (map-get? health-authorities { authority-id: authority-id })) ERR_NOT_FOUND)

    (map-set verified-authorities
      { authority-id: authority-id }
      { verified: true }
    )

    (match (map-get? health-authorities { authority-id: authority-id })
      authority-data
      (map-set health-authorities
        { authority-id: authority-id }
        (merge authority-data { verification-status: "verified", last-updated: block-height })
      )
      false
    )

    (ok true)
  )
)

;; Read-only Functions

;; Get authority information
(define-read-only (get-authority (authority-id uint))
  (map-get? health-authorities { authority-id: authority-id })
)

;; Check if authority is verified
(define-read-only (is-authority-verified (authority-id uint))
  (default-to false (get verified (map-get? verified-authorities { authority-id: authority-id })))
)

;; Get authority ID by principal
(define-read-only (get-authority-id (principal principal))
  (map-get? authority-principals { principal: principal })
)

;; Check if principal is verified authority
(define-read-only (is-verified-authority (principal principal))
  (match (map-get? authority-principals { principal: principal })
    authority-data
    (is-authority-verified (get authority-id authority-data))
    false
  )
)
