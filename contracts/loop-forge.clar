;; LoopForge Main Contract
;; Enhanced version with device management features

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-not-owner (err u100))
(define-constant err-app-exists (err u101))
(define-constant err-device-exists (err u102))
(define-constant err-not-authorized (err u103))
(define-constant err-invalid-app (err u104))
(define-constant err-device-not-found (err u105))
(define-constant err-invalid-metadata (err u106))
(define-constant err-rate-limit-exceeded (err u107))

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
    verified: bool,
    last-updated: uint,
    registration-count: uint
  }
)

;; Rate limiting map
(define-map registration-limits
  { owner: principal }
  { count: uint, reset-height: uint }
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

;; Private functions
(define-private (validate-metadata (metadata (string-utf8 256)))
  (begin
    (asserts! (> (len metadata) u0) err-invalid-metadata)
    (ok true))
)

(define-private (check-rate-limit (caller principal))
  (let ((limit-data (default-to 
    { count: u0, reset-height: block-height }
    (map-get? registration-limits { owner: caller }))))
    (if (> (- block-height (get reset-height limit-data)) u144)
      (begin
        (map-set registration-limits
          { owner: caller }
          { count: u1, reset-height: block-height }
        )
        (ok true))
      (if (< (get count limit-data) u10)
        (begin
          (map-set registration-limits
            { owner: caller }
            { count: (+ (get count limit-data) u1), reset-height: (get reset-height limit-data) }
          )
          (ok true))
        err-rate-limit-exceeded))))

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
  ))

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
    (try! (validate-metadata metadata))
    (try! (check-rate-limit tx-sender))
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
          verified: false,
          last-updated: block-height,
          registration-count: u1
        }
      )
      (emit-event "device-registered" device-id metadata)
      (ok true))))

(define-public (update-device-metadata 
  (device-id (string-ascii 64))
  (metadata (string-utf8 256)))
  (let ((device (map-get? devices {device-id: device-id})))
    (match device
      device-data (begin
        (asserts! (is-eq tx-sender (get owner device-data)) err-not-authorized)
        (try! (validate-metadata metadata))
        (map-set devices
          { device-id: device-id }
          (merge device-data { 
            metadata: metadata,
            last-updated: block-height
          })
        )
        (emit-event "device-updated" device-id metadata)
        (ok true))
      err-device-not-found)))

;; [Previous functions remain unchanged...]

;; Enhanced read-only functions
(define-read-only (get-events-by-range (start-id uint) (end-id uint))
  (begin
    (asserts! (<= start-id end-id) (err u108))
    (asserts! (<= (- end-id start-id) u50) (err u109))
    (ok (map get-event (list start-id end-id)))
  ))
