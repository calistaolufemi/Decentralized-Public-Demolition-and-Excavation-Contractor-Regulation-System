# Decentralized Public Demolition and Excavation Contractor Regulation System

## Overview

This system provides a comprehensive blockchain-based solution for regulating demolition and excavation contractors through five interconnected smart contracts. The system ensures public safety, environmental compliance, and proper oversight of construction-related activities.

## System Architecture

### Core Contracts

1. **Demolition Contractor Licensing** (`demolition-licensing.clar`)
    - Issues and manages permits for building demolition and site clearing
    - Tracks contractor qualifications and certifications
    - Manages permit renewals and revocations

2. **Excavation Safety Oversight** (`excavation-safety.clar`)
    - Monitors trenching and excavation work for worker safety
    - Enforces safety protocols and standards
    - Tracks safety violations and incidents

3. **Hazardous Material Handling** (`hazmat-handling.clar`)
    - Ensures proper removal of asbestos, lead, and other dangerous materials
    - Manages hazmat certifications and protocols
    - Tracks disposal and remediation activities

4. **Utility Location Verification** (`utility-verification.clar`)
    - Requires contractors to locate underground utilities before digging
    - Manages utility marking and verification processes
    - Prevents utility strikes and service disruptions

5. **Debris Disposal Tracking** (`debris-disposal.clar`)
    - Monitors proper disposal of construction and demolition waste
    - Tracks waste streams and disposal locations
    - Ensures environmental compliance

## Key Features

- **Decentralized Governance**: No single point of failure or control
- **Transparent Operations**: All activities recorded on blockchain
- **Automated Compliance**: Smart contract enforcement of regulations
- **Real-time Monitoring**: Live tracking of contractor activities
- **Immutable Records**: Permanent audit trail for all operations

## Data Structures

### Contractor Profile
- Principal address
- License number
- Certification levels
- Insurance information
- Safety record
- Active permits

### Permit Information
- Permit ID
- Project location
- Scope of work
- Duration
- Safety requirements
- Environmental considerations

### Safety Records
- Incident reports
- Violation history
- Training certifications
- Equipment inspections
- Worker safety metrics

## Workflow

1. **Registration**: Contractors register and submit credentials
2. **Licensing**: System validates qualifications and issues permits
3. **Pre-work**: Utility location and hazmat assessment required
4. **Monitoring**: Real-time tracking during active work
5. **Completion**: Final inspections and debris disposal verification

## Security Features

- Multi-signature requirements for critical operations
- Role-based access control
- Automated violation detection
- Emergency shutdown capabilities
- Audit trail preservation

## Compliance Standards

- OSHA safety regulations
- EPA environmental standards
- Local building codes
- Utility protection requirements
- Waste disposal regulations

## Getting Started

1. Deploy contracts to Stacks blockchain
2. Initialize system parameters
3. Register regulatory authorities
4. Begin contractor onboarding
5. Start permit issuance process

## Testing

The system includes comprehensive test coverage using Vitest:
- Unit tests for each contract function
- Integration tests for cross-contract workflows
- Edge case and error condition testing
- Performance and gas optimization tests

## Deployment

Use Clarinet for local development and testing:
\`\`\`bash
clarinet console
clarinet test
clarinet deploy
\`\`\`

## License

This project is licensed under the MIT License - see the LICENSE file for details.
\`\`\`

```clar file="contracts/demolition-licensing.clar"
;; Demolition Contractor Licensing Contract
;; Manages permits for building demolition and site clearing

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-CONTRACTOR (err u101))
(define-constant ERR-PERMIT-EXISTS (err u102))
(define-constant ERR-PERMIT-NOT-FOUND (err u103))
(define-constant ERR-PERMIT-EXPIRED (err u104))
(define-constant ERR-INSUFFICIENT-INSURANCE (err u105))
(define-constant ERR-INVALID-INPUT (err u106))

;; Data Variables
(define-data-var next-permit-id uint u1)
(define-data-var contract-active bool true)

;; Data Maps
(define-map contractors principal {
    license-number: (string-ascii 20),
    company-name: (string-ascii 100),
    insurance-amount: uint,
    certification-level: uint,
    registration-date: uint,
    active: bool
})

(define-map permits uint {
    contractor: principal,
    project-address: (string-ascii 200),
    permit-type: (string-ascii 50),
    issue-date: uint,
    expiry-date: uint,
    project-value: uint,
    status: (string-ascii 20),
    safety-requirements: (list 10 (string-ascii 100))
})

(define-map contractor-permits principal (list 50 uint))

;; Authorization check
(define-private (is-authorized (caller principal))
    (or (is-eq caller CONTRACT-OWNER)
        (is-contract-caller)))

;; Register a new contractor
(define-public (register-contractor 
    (license-number (string-ascii 20))
    (company-name (string-ascii 100))
    (insurance-amount uint)
    (certification-level uint))
    (begin
        (asserts! (var-get contract-active) ERR-NOT-AUTHORIZED)
        (asserts! (> (len license-number) u0) ERR-INVALID-INPUT)
        (asserts! (> (len company-name) u0) ERR-INVALID-INPUT)
        (asserts! (> insurance-amount u0) ERR-INVALID-INPUT)
        (asserts! (and (>= certification-level u1) (&lt;= certification-level u5)) ERR-INVALID-INPUT)
        (asserts! (is-none (map-get? contractors tx-sender)) ERR-INVALID-CONTRACTOR)
        
        (map-set contractors tx-sender {
            license-number: license-number,
            company-name: company-name,
            insurance-amount: insurance-amount,
            certification-level: certification-level,
            registration-date: block-height,
            active: true
        })
        (ok true)))

;; Issue a demolition permit
(define-public (issue-permit
    (contractor principal)
    (project-address (string-ascii 200))
    (permit-type (string-ascii 50))
    (duration-blocks uint)
    (project-value uint)
    (safety-requirements (list 10 (string-ascii 100))))
    (let ((permit-id (var-get next-permit-id))
          (contractor-data (unwrap! (map-get? contractors contractor) ERR-INVALID-CONTRACTOR)))
        (begin
            (asserts! (is-authorized tx-sender) ERR-NOT-AUTHORIZED)
            (asserts! (var-get contract-active) ERR-NOT-AUTHORIZED)
            (asserts! (get active contractor-data) ERR-INVALID-CONTRACTOR)
            (asserts! (> (len project-address) u0) ERR-INVALID-INPUT)
            (asserts! (> duration-blocks u0) ERR-INVALID-INPUT)
            (asserts! (>= (get insurance-amount contractor-data) (/ project-value u10)) ERR-INSUFFICIENT-INSURANCE)
            
            (map-set permits permit-id {
                contractor: contractor,
                project-address: project-address,
                permit-type: permit-type,
                issue-date: block-height,
                expiry-date: (+ block-height duration-blocks),
                project-value: project-value,
                status: "active",
                safety-requirements: safety-requirements
            })
            
            (let ((current-permits (default-to (list) (map-get? contractor-permits contractor))))
                (map-set contractor-permits contractor (unwrap! (as-max-len? (append current-permits permit-id) u50) ERR-INVALID-INPUT)))
            
            (var-set next-permit-id (+ permit-id u1))
            (ok permit-id))))

;; Update permit status
(define-public (update-permit-status (permit-id uint) (new-status (string-ascii 20)))
    (let ((permit-data (unwrap! (map-get? permits permit-id) ERR-PERMIT-NOT-FOUND)))
        (begin
            (asserts! (is-authorized tx-sender) ERR-NOT-AUTHORIZED)
            (asserts! (var-get contract-active) ERR-NOT-AUTHORIZED)
            (asserts! (> (len new-status) u0) ERR-INVALID-INPUT)
            
            (map-set permits permit-id (merge permit-data { status: new-status }))
            (ok true))))

;; Revoke contractor license
(define-public (revoke-contractor (contractor principal))
    (let ((contractor-data (unwrap! (map-get? contractors contractor) ERR-INVALID-CONTRACTOR)))
        (begin
            (asserts! (is-authorized tx-sender) ERR-NOT-AUTHORIZED)
            (asserts! (var-get contract-active) ERR-NOT-AUTHORIZED)
            
            (map-set contractors contractor (merge contractor-data { active: false }))
            (ok true))))

;; Read-only functions
(define-read-only (get-contractor (contractor principal))
    (map-get? contractors contractor))

(define-read-only (get-permit (permit-id uint))
    (map-get? permits permit-id))

(define-read-only (get-contractor-permits (contractor principal))
    (map-get? contractor-permits contractor))

(define-read-only (is-permit-valid (permit-id uint))
    (match (map-get? permits permit-id)
        permit-data (and 
            (is-eq (get status permit-data) "active")
            (&lt; block-height (get expiry-date permit-data)))
        false))

(define-read-only (get-next-permit-id)
    (var-get next-permit-id))

;; Emergency functions
(define-public (emergency-shutdown)
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (var-set contract-active false)
        (ok true)))

(define-public (reactivate-contract)
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (var-set contract-active true)
        (ok true)))
