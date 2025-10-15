;; CacaoNet Farmer Verification Contract
;; Manages farmer credentials and certifications for fair-trade cocoa sourcing

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED u200)
(define-constant ERR_FARMER_NOT_FOUND u201)
(define-constant ERR_FARMER_ALREADY_EXISTS u202)
(define-constant ERR_INVALID_FARMER_DATA u203)
(define-constant ERR_CERTIFICATION_NOT_FOUND u204)
(define-constant ERR_INVALID_CERTIFICATION_DATA u205)
(define-constant ERR_COMPLIANCE_RECORD_EXISTS u206)
(define-constant ERR_INVALID_COORDINATES u207)
(define-constant ERR_EMPTY_STRING u208)
(define-constant ERR_INVALID_FARM_SIZE u209)
(define-constant ERR_FUTURE_DATE u210)

;; Data Variables
(define-data-var contract-admin principal CONTRACT_OWNER)
(define-data-var next-compliance-id uint u1)

;; Data Maps
(define-map farmers
    { farmer: principal }
    {
        name: (string-ascii 100),
        farm-name: (string-ascii 100),
        registration-date: uint,
        farm-latitude: int,
        farm-longitude: int,
        farm-size-hectares: uint,
        contact-info: (string-ascii 200),
        is-active: bool,
        verification-status: (string-ascii 20)
    }
)

(define-map farmer-certifications
    { farmer: principal, certification-type: (string-ascii 30) }
    {
        issuing-authority: (string-ascii 100),
        issue-date: uint,
        expiry-date: uint,
        certification-number: (string-ascii 50),
        is-valid: bool,
        verification-documents: (string-ascii 200)
    }
)

(define-map compliance-records
    { farmer: principal, compliance-id: uint }
    {
        audit-date: uint,
        auditor: principal,
        compliance-type: (string-ascii 50),
        score: uint,
        notes: (string-ascii 300),
        remediation-required: bool,
        remediation-deadline: (optional uint)
    }
)

(define-map authorized-auditors
    { auditor: principal }
    {
        organization: (string-ascii 100),
        accreditation-number: (string-ascii 50),
        authorized-date: uint,
        audit-types: (list 10 (string-ascii 50)),
        is-active: bool
    }
)

(define-map farmer-compliance-counters
    { farmer: principal }
    { next-compliance-id: uint }
)

(define-map certification-authorities
    { authority: principal }
    {
        organization-name: (string-ascii 100),
        accreditation-body: (string-ascii 100),
        authorized-certifications: (list 10 (string-ascii 30)),
        registration-date: uint,
        is-active: bool
    }
)

;; Authorization Functions
(define-private (is-contract-admin (caller principal))
    (is-eq caller (var-get contract-admin))
)

(define-private (is-authorized-auditor (auditor principal))
    (match (map-get? authorized-auditors { auditor: auditor })
        auditor-data (get is-active auditor-data)
        false
    )
)

(define-private (is-authorized-certification-authority (authority principal))
    (match (map-get? certification-authorities { authority: authority })
        authority-data (get is-active authority-data)
        false
    )
)

;; Validation Functions
(define-private (validate-farmer-data (name (string-ascii 100)) (farm-name (string-ascii 100))
                                     (farm-lat int) (farm-lng int) (farm-size uint)
                                     (contact-info (string-ascii 200)))
    (and
        (> (len name) u0)
        (> (len farm-name) u0)
        (> farm-size u0)
        (<= farm-size u10000)  ;; Max 10,000 hectares
        (>= farm-lat -900000)  ;; -90.0000 degrees
        (<= farm-lat 900000)   ;; 90.0000 degrees
        (>= farm-lng -1800000) ;; -180.0000 degrees
        (<= farm-lng 1800000)  ;; 180.0000 degrees
        (> (len contact-info) u0)
    )
)

(define-private (validate-certification-type (cert-type (string-ascii 30)))
    (or
        (is-eq cert-type "fair-trade")
        (is-eq cert-type "organic")
        (is-eq cert-type "rainforest-alliance")
        (is-eq cert-type "utz")
        (is-eq cert-type "c.a.f.e")
        (is-eq cert-type "bird-friendly")
        (is-eq cert-type "demeter-biodynamic")
    )
)

(define-private (validate-compliance-score (score uint))
    (and (>= score u0) (<= score u100))
)

;; Admin Functions
(define-public (set-contract-admin (new-admin principal))
    (begin
        (asserts! (is-contract-admin tx-sender) (err ERR_NOT_AUTHORIZED))
        (ok (var-set contract-admin new-admin))
    )
)

(define-public (add-authorized-auditor (auditor principal)
                                      (organization (string-ascii 100))
                                      (accreditation-number (string-ascii 50))
                                      (audit-types (list 10 (string-ascii 50))))
    (begin
        (asserts! (is-contract-admin tx-sender) (err ERR_NOT_AUTHORIZED))
        (asserts! (> (len organization) u0) (err ERR_EMPTY_STRING))
        (asserts! (> (len accreditation-number) u0) (err ERR_EMPTY_STRING))
        
        (ok (map-set authorized-auditors
            { auditor: auditor }
            {
                organization: organization,
                accreditation-number: accreditation-number,
                authorized-date: stacks-block-height,
                audit-types: audit-types,
                is-active: true
            }
        ))
    )
)

(define-public (add-certification-authority (authority principal)
                                           (organization-name (string-ascii 100))
                                           (accreditation-body (string-ascii 100))
                                           (authorized-certifications (list 10 (string-ascii 30))))
    (begin
        (asserts! (is-contract-admin tx-sender) (err ERR_NOT_AUTHORIZED))
        (asserts! (> (len organization-name) u0) (err ERR_EMPTY_STRING))
        
        (ok (map-set certification-authorities
            { authority: authority }
            {
                organization-name: organization-name,
                accreditation-body: accreditation-body,
                authorized-certifications: authorized-certifications,
                registration-date: stacks-block-height,
                is-active: true
            }
        ))
    )
)

(define-public (deactivate-auditor (auditor principal))
    (begin
        (asserts! (is-contract-admin tx-sender) (err ERR_NOT_AUTHORIZED))
        (match (map-get? authorized-auditors { auditor: auditor })
            auditor-data
            (ok (map-set authorized-auditors
                { auditor: auditor }
                (merge auditor-data { is-active: false })
            ))
            (err ERR_NOT_AUTHORIZED)
        )
    )
)

;; Core Farmer Functions
(define-public (register-farmer (name (string-ascii 100))
                               (farm-name (string-ascii 100))
                               (farm-latitude int)
                               (farm-longitude int)
                               (farm-size-hectares uint)
                               (contact-info (string-ascii 200)))
    (begin
        (asserts! (validate-farmer-data name farm-name farm-latitude farm-longitude 
                                       farm-size-hectares contact-info) 
                  (err ERR_INVALID_FARMER_DATA))
        (asserts! (is-none (map-get? farmers { farmer: tx-sender })) (err ERR_FARMER_ALREADY_EXISTS))
        
        (map-set farmers
            { farmer: tx-sender }
            {
                name: name,
                farm-name: farm-name,
                registration-date: stacks-block-height,
                farm-latitude: farm-latitude,
                farm-longitude: farm-longitude,
                farm-size-hectares: farm-size-hectares,
                contact-info: contact-info,
                is-active: true,
                verification-status: "pending"
            }
        )
        
        (map-set farmer-compliance-counters { farmer: tx-sender } { next-compliance-id: u1 })
        
        (ok true)
    )
)

(define-public (update-farmer-status (farmer principal) (new-status (string-ascii 20)))
    (begin
        (asserts! (is-contract-admin tx-sender) (err ERR_NOT_AUTHORIZED))
        (asserts! (is-some (map-get? farmers { farmer: farmer })) (err ERR_FARMER_NOT_FOUND))
        
        (match (map-get? farmers { farmer: farmer })
            farmer-data
            (ok (map-set farmers
                { farmer: farmer }
                (merge farmer-data { verification-status: new-status })
            ))
            (err ERR_FARMER_NOT_FOUND)
        )
    )
)

(define-public (add-farmer-certification (farmer principal)
                                        (certification-type (string-ascii 30))
                                        (issuing-authority (string-ascii 100))
                                        (expiry-date uint)
                                        (certification-number (string-ascii 50))
                                        (verification-documents (string-ascii 200)))
    (begin
        (asserts! (is-authorized-certification-authority tx-sender) (err ERR_NOT_AUTHORIZED))
        (asserts! (is-some (map-get? farmers { farmer: farmer })) (err ERR_FARMER_NOT_FOUND))
        (asserts! (validate-certification-type certification-type) (err ERR_INVALID_CERTIFICATION_DATA))
        (asserts! (> expiry-date stacks-block-height) (err ERR_FUTURE_DATE))
        (asserts! (> (len certification-number) u0) (err ERR_EMPTY_STRING))
        
        (ok (map-set farmer-certifications
            { farmer: farmer, certification-type: certification-type }
            {
                issuing-authority: issuing-authority,
                issue-date: stacks-block-height,
                expiry-date: expiry-date,
                certification-number: certification-number,
                is-valid: true,
                verification-documents: verification-documents
            }
        ))
    )
)

(define-public (add-compliance-record (farmer principal)
                                     (compliance-type (string-ascii 50))
                                     (score uint)
                                     (notes (string-ascii 300))
                                     (remediation-required bool)
                                     (remediation-deadline (optional uint)))
    (begin
        (asserts! (is-authorized-auditor tx-sender) (err ERR_NOT_AUTHORIZED))
        (asserts! (is-some (map-get? farmers { farmer: farmer })) (err ERR_FARMER_NOT_FOUND))
        (asserts! (validate-compliance-score score) (err ERR_INVALID_CERTIFICATION_DATA))
        (asserts! (> (len compliance-type) u0) (err ERR_EMPTY_STRING))
        
        (let ((compliance-id (default-to u1 (get next-compliance-id 
                                            (map-get? farmer-compliance-counters { farmer: farmer })))))
            (map-set compliance-records
                { farmer: farmer, compliance-id: compliance-id }
                {
                    audit-date: stacks-block-height,
                    auditor: tx-sender,
                    compliance-type: compliance-type,
                    score: score,
                    notes: notes,
                    remediation-required: remediation-required,
                    remediation-deadline: remediation-deadline
                }
            )
            
            (map-set farmer-compliance-counters
                { farmer: farmer }
                { next-compliance-id: (+ compliance-id u1) }
            )
            
            (ok compliance-id)
        )
    )
)

(define-public (update-contact-info (new-contact-info (string-ascii 200)))
    (begin
        (asserts! (is-some (map-get? farmers { farmer: tx-sender })) (err ERR_FARMER_NOT_FOUND))
        (asserts! (> (len new-contact-info) u0) (err ERR_EMPTY_STRING))
        
        (match (map-get? farmers { farmer: tx-sender })
            farmer-data
            (ok (map-set farmers
                { farmer: tx-sender }
                (merge farmer-data { contact-info: new-contact-info })
            ))
            (err ERR_FARMER_NOT_FOUND)
        )
    )
)

(define-public (deactivate-farmer (farmer principal))
    (begin
        (asserts! (is-contract-admin tx-sender) (err ERR_NOT_AUTHORIZED))
        (match (map-get? farmers { farmer: farmer })
            farmer-data
            (ok (map-set farmers
                { farmer: farmer }
                (merge farmer-data { is-active: false })
            ))
            (err ERR_FARMER_NOT_FOUND)
        )
    )
)

;; Read-only Functions
(define-read-only (get-farmer-info (farmer principal))
    (map-get? farmers { farmer: farmer })
)

(define-read-only (get-farmer-certification (farmer principal) (certification-type (string-ascii 30)))
    (map-get? farmer-certifications { farmer: farmer, certification-type: certification-type })
)

(define-read-only (get-compliance-record (farmer principal) (compliance-id uint))
    (map-get? compliance-records { farmer: farmer, compliance-id: compliance-id })
)

(define-read-only (get-authorized-auditor (auditor principal))
    (map-get? authorized-auditors { auditor: auditor })
)

(define-read-only (get-certification-authority (authority principal))
    (map-get? certification-authorities { authority: authority })
)

(define-read-only (verify-farmer (farmer principal))
    (match (map-get? farmers { farmer: farmer })
        farmer-data
        (and
            (get is-active farmer-data)
            (is-eq (get verification-status farmer-data) "verified")
        )
        false
    )
)

(define-read-only (check-certification-validity (farmer principal) (certification-type (string-ascii 30)))
    (match (map-get? farmer-certifications { farmer: farmer, certification-type: certification-type })
        cert-data
        (and
            (get is-valid cert-data)
            (> (get expiry-date cert-data) stacks-block-height)
        )
        false
    )
)

(define-read-only (check-fair-trade-eligibility (farmer principal))
    (and
        (verify-farmer farmer)
        (check-certification-validity farmer "fair-trade")
    )
)

(define-read-only (get-farmer-compliance-score (farmer principal))
    ;; Returns the latest compliance score for a farmer
    (let ((compliance-counter (default-to u1 (get next-compliance-id 
                                             (map-get? farmer-compliance-counters { farmer: farmer })))))
        (if (> compliance-counter u1)
            (match (map-get? compliance-records { farmer: farmer, compliance-id: (- compliance-counter u1) })
                record-data (some (get score record-data))
                none
            )
            none
        )
    )
)

(define-read-only (get-contract-admin)
    (var-get contract-admin)
)

(define-read-only (is-farmer-active (farmer principal))
    (match (map-get? farmers { farmer: farmer })
        farmer-data (get is-active farmer-data)
        false
    )
)

(define-read-only (get-farmer-verification-status (farmer principal))
    (match (map-get? farmers { farmer: farmer })
        farmer-data (some (get verification-status farmer-data))
        none
    )
)

;; title: farmer-verification
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

