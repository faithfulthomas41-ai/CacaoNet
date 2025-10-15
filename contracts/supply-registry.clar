;; CacaoNet Supply Registry Contract
;; Tracks cocoa batches throughout the supply chain with fair-trade verification

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED u100)
(define-constant ERR_BATCH_NOT_FOUND u101)
(define-constant ERR_INVALID_BATCH_DATA u102)
(define-constant ERR_BATCH_ALREADY_EXISTS u103)
(define-constant ERR_INVALID_CERTIFICATION u104)
(define-constant ERR_INVALID_OWNERSHIP_TRANSFER u105)
(define-constant ERR_PROCESSING_STAGE_EXISTS u106)
(define-constant ERR_INVALID_QUANTITY u107)
(define-constant ERR_FUTURE_DATE u108)
(define-constant ERR_EMPTY_STRING u109)

;; Data Variables
(define-data-var next-batch-id uint u1)
(define-data-var contract-admin principal CONTRACT_OWNER)

;; Data Maps
(define-map batches
    { batch-id: uint }
    {
        farmer: principal,
        origin-latitude: int,
        origin-longitude: int,
        harvest-date: uint,
        quantity-kg: uint,
        quality-grade: (string-ascii 20),
        current-owner: principal,
        registration-date: uint,
        is-active: bool
    }
)

(define-map batch-certifications
    { batch-id: uint, certification-type: (string-ascii 30) }
    {
        certifier: principal,
        certification-date: uint,
        expiry-date: uint,
        is-valid: bool
    }
)

(define-map processing-stages
    { batch-id: uint, stage-id: uint }
    {
        stage-name: (string-ascii 50),
        processor: principal,
        processing-date: uint,
        location: (string-ascii 100),
        notes: (string-ascii 200)
    }
)

(define-map ownership-history
    { batch-id: uint, transfer-id: uint }
    {
        from-owner: principal,
        to-owner: principal,
        transfer-date: uint,
        transfer-reason: (string-ascii 100)
    }
)

(define-map authorized-certifiers
    { certifier: principal }
    {
        organization: (string-ascii 100),
        certification-types: (list 10 (string-ascii 30)),
        authorized-date: uint,
        is-active: bool
    }
)

(define-map batch-stage-counters
    { batch-id: uint }
    { next-stage-id: uint }
)

(define-map batch-transfer-counters
    { batch-id: uint }
    { next-transfer-id: uint }
)

;; Authorization Functions
(define-private (is-contract-admin (caller principal))
    (is-eq caller (var-get contract-admin))
)

(define-private (is-batch-owner (batch-id uint) (caller principal))
    (match (map-get? batches { batch-id: batch-id })
        batch-data (is-eq caller (get current-owner batch-data))
        false
    )
)

(define-private (is-authorized-certifier (certifier principal))
    (match (map-get? authorized-certifiers { certifier: certifier })
        certifier-data (get is-active certifier-data)
        false
    )
)

;; Validation Functions
(define-private (validate-batch-data (farmer principal) (origin-lat int) (origin-lng int)
                                    (harvest-date uint) (quantity-kg uint) (quality-grade (string-ascii 20)))
    (and
        (> quantity-kg u0)
        (<= harvest-date stacks-block-height)
        (> (len quality-grade) u0)
        (<= (len quality-grade) u20)
        (>= origin-lat -900000)  ;; -90.0000 degrees
        (<= origin-lat 900000)   ;; 90.0000 degrees
        (>= origin-lng -1800000) ;; -180.0000 degrees
        (<= origin-lng 1800000)  ;; 180.0000 degrees
    )
)

(define-private (validate-certification-type (cert-type (string-ascii 30)))
    (or
        (is-eq cert-type "fair-trade")
        (is-eq cert-type "organic")
        (is-eq cert-type "rainforest-alliance")
        (is-eq cert-type "utz")
        (is-eq cert-type "iso-22000")
        (is-eq cert-type "haccp")
    )
)

;; Admin Functions
(define-public (set-contract-admin (new-admin principal))
    (begin
        (asserts! (is-contract-admin tx-sender) (err ERR_NOT_AUTHORIZED))
        (ok (var-set contract-admin new-admin))
    )
)

(define-public (add-authorized-certifier (certifier principal) 
                                        (organization (string-ascii 100))
                                        (cert-types (list 10 (string-ascii 30))))
    (begin
        (asserts! (is-contract-admin tx-sender) (err ERR_NOT_AUTHORIZED))
        (asserts! (> (len organization) u0) (err ERR_EMPTY_STRING))
        (ok (map-set authorized-certifiers
            { certifier: certifier }
            {
                organization: organization,
                certification-types: cert-types,
                authorized-date: stacks-block-height,
                is-active: true
            }
        ))
    )
)

(define-public (deactivate-certifier (certifier principal))
    (begin
        (asserts! (is-contract-admin tx-sender) (err ERR_NOT_AUTHORIZED))
        (match (map-get? authorized-certifiers { certifier: certifier })
            certifier-data
            (ok (map-set authorized-certifiers
                { certifier: certifier }
                (merge certifier-data { is-active: false })
            ))
            (err ERR_NOT_AUTHORIZED)
        )
    )
)

;; Core Batch Functions
(define-public (register-batch (farmer principal) 
                              (origin-latitude int)
                              (origin-longitude int)
                              (harvest-date uint)
                              (quantity-kg uint)
                              (quality-grade (string-ascii 20)))
    (let ((batch-id (var-get next-batch-id)))
        (asserts! (validate-batch-data farmer origin-latitude origin-longitude 
                                     harvest-date quantity-kg quality-grade) 
                  (err ERR_INVALID_BATCH_DATA))
        (asserts! (is-none (map-get? batches { batch-id: batch-id })) (err ERR_BATCH_ALREADY_EXISTS))
        
        (map-set batches
            { batch-id: batch-id }
            {
                farmer: farmer,
                origin-latitude: origin-latitude,
                origin-longitude: origin-longitude,
                harvest-date: harvest-date,
                quantity-kg: quantity-kg,
                quality-grade: quality-grade,
                current-owner: farmer,
                registration-date: stacks-block-height,
                is-active: true
            }
        )
        
        (map-set batch-stage-counters { batch-id: batch-id } { next-stage-id: u1 })
        (map-set batch-transfer-counters { batch-id: batch-id } { next-transfer-id: u1 })
        
        (var-set next-batch-id (+ batch-id u1))
        (ok batch-id)
    )
)

(define-public (certify-batch (batch-id uint) 
                             (certification-type (string-ascii 30))
                             (expiry-date uint))
    (begin
        (asserts! (is-authorized-certifier tx-sender) (err ERR_NOT_AUTHORIZED))
        (asserts! (is-some (map-get? batches { batch-id: batch-id })) (err ERR_BATCH_NOT_FOUND))
        (asserts! (validate-certification-type certification-type) (err ERR_INVALID_CERTIFICATION))
        (asserts! (> expiry-date stacks-block-height) (err ERR_FUTURE_DATE))
        
        (ok (map-set batch-certifications
            { batch-id: batch-id, certification-type: certification-type }
            {
                certifier: tx-sender,
                certification-date: stacks-block-height,
                expiry-date: expiry-date,
                is-valid: true
            }
        ))
    )
)

(define-public (transfer-ownership (batch-id uint) 
                                  (new-owner principal)
                                  (transfer-reason (string-ascii 100)))
    (begin
        (asserts! (is-batch-owner batch-id tx-sender) (err ERR_NOT_AUTHORIZED))
        (asserts! (not (is-eq tx-sender new-owner)) (err ERR_INVALID_OWNERSHIP_TRANSFER))
        (asserts! (> (len transfer-reason) u0) (err ERR_EMPTY_STRING))
        
        (match (map-get? batches { batch-id: batch-id })
            batch-data
            (let ((transfer-id (default-to u1 (get next-transfer-id 
                                              (map-get? batch-transfer-counters { batch-id: batch-id })))))
                (map-set ownership-history
                    { batch-id: batch-id, transfer-id: transfer-id }
                    {
                        from-owner: tx-sender,
                        to-owner: new-owner,
                        transfer-date: stacks-block-height,
                        transfer-reason: transfer-reason
                    }
                )
                
                (map-set batches
                    { batch-id: batch-id }
                    (merge batch-data { current-owner: new-owner })
                )
                
                (map-set batch-transfer-counters 
                    { batch-id: batch-id } 
                    { next-transfer-id: (+ transfer-id u1) })
                
                (ok transfer-id)
            )
            (err ERR_BATCH_NOT_FOUND)
        )
    )
)

(define-public (add-processing-stage (batch-id uint)
                                    (stage-name (string-ascii 50))
                                    (location (string-ascii 100))
                                    (notes (string-ascii 200)))
    (begin
        (asserts! (is-batch-owner batch-id tx-sender) (err ERR_NOT_AUTHORIZED))
        (asserts! (> (len stage-name) u0) (err ERR_EMPTY_STRING))
        
        (match (map-get? batches { batch-id: batch-id })
            batch-data
            (let ((stage-id (default-to u1 (get next-stage-id 
                                           (map-get? batch-stage-counters { batch-id: batch-id })))))
                (map-set processing-stages
                    { batch-id: batch-id, stage-id: stage-id }
                    {
                        stage-name: stage-name,
                        processor: tx-sender,
                        processing-date: stacks-block-height,
                        location: location,
                        notes: notes
                    }
                )
                
                (map-set batch-stage-counters 
                    { batch-id: batch-id } 
                    { next-stage-id: (+ stage-id u1) })
                
                (ok stage-id)
            )
            (err ERR_BATCH_NOT_FOUND)
        )
    )
)

;; Read-only Functions
(define-read-only (get-batch-info (batch-id uint))
    (map-get? batches { batch-id: batch-id })
)

(define-read-only (get-batch-certification (batch-id uint) (certification-type (string-ascii 30)))
    (map-get? batch-certifications { batch-id: batch-id, certification-type: certification-type })
)

(define-read-only (get-processing-stage (batch-id uint) (stage-id uint))
    (map-get? processing-stages { batch-id: batch-id, stage-id: stage-id })
)

(define-read-only (get-ownership-transfer (batch-id uint) (transfer-id uint))
    (map-get? ownership-history { batch-id: batch-id, transfer-id: transfer-id })
)

(define-read-only (get-authorized-certifier (certifier principal))
    (map-get? authorized-certifiers { certifier: certifier })
)

(define-read-only (verify-certification (batch-id uint) (certification-type (string-ascii 30)))
    (match (map-get? batch-certifications { batch-id: batch-id, certification-type: certification-type })
        cert-data
        (and
            (get is-valid cert-data)
            (> (get expiry-date cert-data) stacks-block-height)
        )
        false
    )
)

(define-read-only (get-current-batch-id)
    (var-get next-batch-id)
)

(define-read-only (get-contract-admin)
    (var-get contract-admin)
)

(define-read-only (is-batch-active (batch-id uint))
    (match (map-get? batches { batch-id: batch-id })
        batch-data (get is-active batch-data)
        false
    )
)

;; title: supply-registry
;; version:
;; summary:
;; description:

;; traits
;;

;; token definitions
;;

;; constants
;;

;; data vars
;;

;; data maps
;;

;; public functions
;;

;; read only functions
;;

;; private functions
;;

