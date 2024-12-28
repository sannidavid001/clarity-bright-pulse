;; BrightPulse - Decentralized Idea Sharing Platform

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-invalid-idea (err u101))
(define-constant err-already-voted (err u102))
(define-constant err-not-found (err u103))

;; Data Variables
(define-data-var next-idea-id uint u0)
(define-data-var reward-per-vote uint u10) ;; Base reward points for voting

;; Data Maps
(define-map ideas 
    uint 
    {
        author: principal,
        title: (string-ascii 100),
        description: (string-utf8 1000),
        votes: uint,
        timestamp: uint
    }
)

(define-map user-votes
    {idea-id: uint, voter: principal}
    bool
)

(define-map user-points
    principal
    uint
)

(define-map comments
    {idea-id: uint, comment-id: uint}
    {
        author: principal,
        content: (string-utf8 500),
        timestamp: uint
    }
)

;; Private Functions
(define-private (increment-idea-id)
    (let ((current (var-get next-idea-id)))
        (var-set next-idea-id (+ current u1))
        current
    )
)

;; Public Functions
(define-public (submit-idea (title (string-ascii 100)) (description (string-utf8 1000)))
    (let ((idea-id (increment-idea-id)))
        (map-set ideas idea-id {
            author: tx-sender,
            title: title,
            description: description,
            votes: u0,
            timestamp: block-height
        })
        (ok idea-id)
    )
)

(define-public (vote-on-idea (idea-id uint))
    (let (
        (idea (unwrap! (map-get? ideas idea-id) err-not-found))
        (has-voted (default-to false (map-get? user-votes {idea-id: idea-id, voter: tx-sender})))
    )
        (asserts! (not has-voted) err-already-voted)
        
        ;; Update vote count
        (map-set ideas idea-id (merge idea {votes: (+ (get votes idea) u1)}))
        
        ;; Record the vote
        (map-set user-votes {idea-id: idea-id, voter: tx-sender} true)
        
        ;; Award points
        (let ((current-points (default-to u0 (map-get? user-points tx-sender))))
            (map-set user-points tx-sender (+ current-points (var-get reward-per-vote)))
        )
        
        (ok true)
    )
)

(define-public (add-comment (idea-id uint) (content (string-utf8 500)))
    (let (
        (idea (unwrap! (map-get? ideas idea-id) err-not-found))
        (comment-id (default-to u0 (map-get? comment-counter idea-id)))
    )
        (map-set comments 
            {idea-id: idea-id, comment-id: comment-id}
            {
                author: tx-sender,
                content: content,
                timestamp: block-height
            }
        )
        (ok true)
    )
)

;; Read-only Functions
(define-read-only (get-idea (idea-id uint))
    (ok (map-get? ideas idea-id))
)

(define-read-only (get-user-points (user principal))
    (ok (default-to u0 (map-get? user-points user)))
)

(define-read-only (get-comment (idea-id uint) (comment-id uint))
    (ok (map-get? comments {idea-id: idea-id, comment-id: comment-id}))
)

;; Admin Functions
(define-public (set-reward-per-vote (amount uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (var-set reward-per-vote amount)
        (ok true)
    )
)