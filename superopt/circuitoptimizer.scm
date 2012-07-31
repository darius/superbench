;; in Chicken Scheme

(define (main args)
  (superopt (car args)
            (if (<= 2 (length args))
                (string->number (cadr args))
                6)))

(define (superopt truth-table max-gates)
  (let ((n-inputs (the-integer (log2 (string-length truth-table)))))
    (find-circuits (string->number truth-table 2) n-inputs max-gates)))

(define (the-integer x)
  (if (integer? x) 
      (inexact->exact x)
      (error "Not an integer" x)))

(define (log2 n)
  ;; XXX This code: (/ (log n) (log 2))) apparently produces a
  ;; noninteger result when compiled (but not when interpreted)
  ;; so here's a really stupid stopgap that does work:
  (case n
    ((1) 0)
    ((2) 1)
    ((4) 2)
    ((8) 3)
    ((16) 4)
    ((32) 5)
    (else (error "XXX"))))

(define (pow2 n)
  (arithmetic-shift 1 n))

(define (find-circuits wanted n-inputs max-gates)
  (let ((inputs (tabulate-inputs n-inputs))
        (mask (- (pow2 (pow2 n-inputs)) 1)))

    (define (find-for-n n-gates)
      (say "Trying " n-gates " gates..." #\newline)
      (let* ((n-wires (+ n-inputs n-gates))
             (L-input (make-vector n-gates #f))
             (R-input (make-vector n-gates #f))
             (wire (list->vector (append inputs (vector->list L-input))))
             (found? #f))
        (let sweeping ((gate 0))
          (do ((L 0 (+ L 1)))  ((= L (+ n-inputs gate)))
            (let ((L-wire (vector-ref wire L)))
              (vector-set! L-input gate L)
              (do ((R 0 (+ R 1)))  ((= R (+ L 1)))
                (let ((value (nand L-wire (vector-ref wire R))))
                  (vector-set! R-input gate R)
                  (vector-set! wire (+ n-inputs gate) value)
                  (cond ((< (+ gate 1) n-gates)
                         (sweeping (+ gate 1)))
                        ((= wanted (bitwise-and mask value))
                         (set! found? #t)
                         (print-formula L-input R-input)))))))
          found?)))

    (define (print-formula L-input R-input)
      (do ((i 0 (+ i 1)))
          ((= i (vector-length L-input)))
        (say (string-ref v-name (+ i n-inputs))
             " = ~(" (string-ref v-name (vector-ref L-input i))
             " " (string-ref v-name (vector-ref R-input i))
             "); "))
      (newline))

    (define v-name (string-append (substring "ABCDEF" 0 n-inputs)
                                  (substring "abcdefghijklmnopqrstuvwxyz"
                                             n-inputs)))

    (some? find-for-n (iota1 max-gates))))

(define (nand x y)
  (bitwise-not (bitwise-and x y)))

(define (say . things)
  (for-each display things))

(define (some? ok? xs)
  (and (not (null? xs))
       (or (ok? (car xs))
           (some? ok? (cdr xs)))))

(define (iota1 n)
  (let loop ((i 1))
    (if (< n i)
        '()
        (cons i (loop (+ i 1))))))

(define (tabulate-inputs n-inputs)
  ; An inputs vector is a vector of n-inputs bitvectors. It holds all
  ; possible input patterns 'transposed': that is, the kth test case
  ; can be formed out of bit #k of each the list's elements, one
  ; element per circuit input. Transposed is the most useful form
  ; because we can compute all test cases in parallel with bitwise
  ; operators.
  (if (= n-inputs 0)
      '()
      (let ((shift (pow2 (- n-inputs 1))))
        (cons (- (pow2 shift) 1)
              (map (lambda (iv) (bitwise-ior iv (arithmetic-shift iv shift)))
                   (tabulate-inputs (- n-inputs 1)))))))
