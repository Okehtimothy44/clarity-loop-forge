;; LoopForge Main Contract

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-not-owner (err u100))
(define-constant err-app-exists (err u101))
(define-constant err-device-exists (err u102))
(define-constant err-not-authorized (err u103))

;; Data structures
(define-map apps
  { app-id: uint }
  {
    owner: principal,
    name: (string-ascii 64),
    created-at: uint,
    active: bool
  }
)

(define-map devices
  { device-id: (string-ascii 64) }
  {
    app-id: uint,
    owner: principal,
    metadata: (string-utf8 256),
    active: bool
  }
)

;; Counter for app IDs
(define-data-var next-app-id uint u1)

;; Public functions
(define-public (create-app (name (string-ascii 64)))
  (let ((app-id (var-get next-app-id)))
    (if (is-eq tx-sender contract-owner)
      (begin
        (map-set apps
          { app-id: app-id }
          {
            owner: tx-sender,
            name: name,
            created-at: block-height,
            active: true
          }
        )
        (var-set next-app-id (+ app-id u1))
        (ok app-id))
      err-not-owner)))

(define-public (register-device 
  (device-id (string-ascii 64))
  (app-id uint)
  (metadata (string-utf8 256)))
  (let ((existing-device (map-get? devices {device-id: device-id})))
    (if (is-none existing-device)
      (begin
        (map-set devices
          { device-id: device-id }
          {
            app-id: app-id,
            owner: tx-sender,
            metadata: metadata,
            active: true
          }
        )
        (ok true))
      err-device-exists)))

;; Read only functions
(define-read-only (get-app (app-id uint))
  (map-get? apps {app-id: app-id}))

(define-read-only (get-device (device-id (string-ascii 64)))
  (map-get? devices {device-id: device-id}))
