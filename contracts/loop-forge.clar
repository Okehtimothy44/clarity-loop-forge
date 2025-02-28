;; LoopForge Main Contract

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-not-owner (err u100))
(define-constant err-app-exists (err u101))
(define-constant err-device-exists (err u102))
(define-constant err-not-authorized (err u103))
(define-constant err-invalid-app (err u104))
(define-constant err-device-not-found (err u105))

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
    active: bool,
    verified: bool
  }
)

;; Counter for app IDs
(define-data-var next-app-id uint u1)

;; Events
(define-data-var last-event-id uint u0)

(define-map events
  { event-id: uint }
  {
    event-type: (string-ascii 32),
    entity-id: (string-ascii 64),
    data: (string-utf8 256),
    timestamp: uint
  }
)

;; Event helper
(define-private (emit-event (event-type (string-ascii 32)) (entity-id (string-ascii 64)) (data (string-utf8 256)))
  (let ((event-id (+ (var-get last-event-id) u1)))
    (begin
      (map-set events
        { event-id: event-id }
        {
          event-type: event-type,
          entity-id: entity-id,
          data: data,
          timestamp: block-height
        }
      )
      (var-set last-event-id event-id)
      (ok event-id)
    )
  )
)

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
        (emit-event "app-created" (to-ascii app-id) (string-utf8-concat "{\"name\": \"" name "\"}"))
        (ok app-id))
      err-not-owner)))

(define-public (register-device 
  (device-id (string-ascii 64))
  (app-id uint)
  (metadata (string-utf8 256)))
  (let (
    (existing-device (map-get? devices {device-id: device-id}))
    (app (map-get? apps {app-id: app-id}))
  )
    (asserts! (is-some app) err-invalid-app)
    (asserts! (is-none existing-device) err-device-exists)
    (begin
      (map-set devices
        { device-id: device-id }
        {
          app-id: app-id,
          owner: tx-sender,
          metadata: metadata,
          active: true,
          verified: false
        }
      )
      (emit-event "device-registered" device-id metadata)
      (ok true))))

(define-public (deactivate-device (device-id (string-ascii 64)))
  (let ((device (map-get? devices {device-id: device-id})))
    (match device
      device-data (begin
        (asserts! (is-eq tx-sender (get owner device-data)) err-not-authorized)
        (map-set devices
          { device-id: device-id }
          (merge device-data { active: false })
        )
        (emit-event "device-deactivated" device-id "")
        (ok true))
      err-device-not-found)))

(define-public (verify-device (device-id (string-ascii 64)))
  (let ((device (map-get? devices {device-id: device-id})))
    (match device
      device-data (begin
        (asserts! (is-eq tx-sender contract-owner) err-not-authorized)
        (map-set devices
          { device-id: device-id }
          (merge device-data { verified: true })
        )
        (emit-event "device-verified" device-id "")
        (ok true))
      err-device-not-found)))

;; Read only functions
(define-read-only (get-app (app-id uint))
  (map-get? apps {app-id: app-id}))

(define-read-only (get-device (device-id (string-ascii 64)))
  (map-get? devices {device-id: device-id}))

(define-read-only (get-event (event-id uint))
  (map-get? events {event-id: event-id}))
