;; Excavation Safety Oversight Contract
;; Monitors trenching and excavation work for worker safety

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u200))
(define-constant ERR-INVALID-CONTRACTOR (err u201))
(define-constant ERR-SAFETY-PLAN-NOT-FOUND (err u202))
(define-constant ERR-VIOLATION-EXISTS (err u203))
(define-constant ERR-INVALID-INPUT (err u204))
(define-constant ERR-UNSAFE-CONDITIONS (err u205))

;; Data Variables
(define-data-var next-plan-id uint u1)
(define-data-var next-violation-id uint u1)
(define-data-var contract-active bool true)

;; Data Maps
(define-map safety-plans uint {
    contractor: principal,
    project-location: (string-ascii 200),
    excavation-depth: uint,
    soil-type: (string-ascii 50),
    safety-measures: (list 20 (string-ascii 100)),
    inspector: principal,
    approval-date: uint,
    status: (string-ascii 20)
})

(define-map safety-violations uint {
    contractor: principal,
    violation-type: (string-ascii 100),
    severity: uint,
    description: (string-ascii 500),
    date-reported: uint,
    fine-amount: uint,
    resolved: bool
})

(define-map contractor-violations principal (list 100 uint))
(define-map daily-inspections (tuple (contractor principal) (date uint)) {
    inspector: principal,
    safety-score: uint,
    violations-found: uint,
    notes: (string-ascii 500)
})

;; Authorization check
(define-private (is-authorized (caller principal))
    (is-eq caller CONTRACT-OWNER))

;; Submit safety plan
(define-public (submit-safety-plan
    (contractor principal)
    (project-location (string-ascii 200))
    (excavation-depth uint)
    (soil-type (string-ascii 50))
    (safety-measures (list 20 (string-ascii 100))))
    (let ((plan-id (var-get next-plan-id)))
        (begin
            (asserts! (var-get contract-active) ERR-NOT-AUTHORIZED)
            (asserts! (> (len project-location) u0) ERR-INVALID-INPUT)
            (asserts! (> excavation-depth u0) ERR-INVALID-INPUT)
            (asserts! (> (len soil-type) u0) ERR-INVALID-INPUT)
            (asserts! (> (len safety-measures) u0) ERR-INVALID-INPUT)

            (map-set safety-plans plan-id {
                contractor: contractor,
                project-location: project-location,
                excavation-depth: excavation-depth,
                soil-type: soil-type,
                safety-measures: safety-measures,
                inspector: tx-sender,
                approval-date: block-height,
                status: "pending"
            })

            (var-set next-plan-id (+ plan-id u1))
            (ok plan-id))))

;; Approve safety plan
(define-public (approve-safety-plan (plan-id uint))
    (let ((plan-data (unwrap! (map-get? safety-plans plan-id) ERR-SAFETY-PLAN-NOT-FOUND)))
        (begin
            (asserts! (is-authorized tx-sender) ERR-NOT-AUTHORIZED)
            (asserts! (var-get contract-active) ERR-NOT-AUTHORIZED)
            (asserts! (is-eq (get status plan-data) "pending") ERR-INVALID-INPUT)

            ;; Safety validation based on depth
            (asserts! (or
                (< (get excavation-depth plan-data) u5)
                (> (len (get safety-measures plan-data)) u5)) ERR-UNSAFE-CONDITIONS)

            (map-set safety-plans plan-id (merge plan-data {
                status: "approved",
                inspector: tx-sender
            }))
            (ok true))))

;; Report safety violation
(define-public (report-violation
    (contractor principal)
    (violation-type (string-ascii 100))
    (severity uint)
    (description (string-ascii 500))
    (fine-amount uint))
    (let ((violation-id (var-get next-violation-id)))
        (begin
            (asserts! (is-authorized tx-sender) ERR-NOT-AUTHORIZED)
            (asserts! (var-get contract-active) ERR-NOT-AUTHORIZED)
            (asserts! (> (len violation-type) u0) ERR-INVALID-INPUT)
            (asserts! (and (>= severity u1) (<= severity u5)) ERR-INVALID-INPUT)
            (asserts! (> (len description) u0) ERR-INVALID-INPUT)

            (map-set safety-violations violation-id {
                contractor: contractor,
                violation-type: violation-type,
                severity: severity,
                description: description,
                date-reported: block-height,
                fine-amount: fine-amount,
                resolved: false
            })

            (let ((current-violations (default-to (list) (map-get? contractor-violations contractor))))
                (map-set contractor-violations contractor
                    (unwrap! (as-max-len? (append current-violations violation-id) u100) ERR-INVALID-INPUT)))

            (var-set next-violation-id (+ violation-id u1))
            (ok violation-id))))

;; Conduct daily inspection
(define-public (conduct-inspection
    (contractor principal)
    (safety-score uint)
    (violations-found uint)
    (notes (string-ascii 500)))
    (begin
        (asserts! (is-authorized tx-sender) ERR-NOT-AUTHORIZED)
        (asserts! (var-get contract-active) ERR-NOT-AUTHORIZED)
        (asserts! (and (>= safety-score u0) (<= safety-score u100)) ERR-INVALID-INPUT)

        (map-set daily-inspections { contractor: contractor, date: block-height } {
            inspector: tx-sender,
            safety-score: safety-score,
            violations-found: violations-found,
            notes: notes
        })
        (ok true)))

;; Resolve violation
(define-public (resolve-violation (violation-id uint))
    (let ((violation-data (unwrap! (map-get? safety-violations violation-id) ERR-SAFETY-PLAN-NOT-FOUND)))
        (begin
            (asserts! (is-authorized tx-sender) ERR-NOT-AUTHORIZED)
            (asserts! (var-get contract-active) ERR-NOT-AUTHORIZED)
            (asserts! (not (get resolved violation-data)) ERR-INVALID-INPUT)

            (map-set safety-violations violation-id (merge violation-data { resolved: true }))
            (ok true))))

;; Read-only functions
(define-read-only (get-safety-plan (plan-id uint))
    (map-get? safety-plans plan-id))

(define-read-only (get-violation (violation-id uint))
    (map-get? safety-violations violation-id))

(define-read-only (get-contractor-violations (contractor principal))
    (map-get? contractor-violations contractor))

(define-read-only (get-inspection (contractor principal) (date uint))
    (map-get? daily-inspections { contractor: contractor, date: date }))

(define-read-only (calculate-safety-rating (contractor principal))
    (let ((violations (default-to (list) (map-get? contractor-violations contractor))))
        (if (is-eq (len violations) u0)
            u100
            (- u100 (* (len violations) u5)))))

;; Emergency functions
(define-public (emergency-shutdown)
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (var-set contract-active false)
        (ok true)))
