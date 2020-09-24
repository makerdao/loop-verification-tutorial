```smt2

(set-option :auto-config false)
(set-option :smt.mbqi false)
;(set-option :smt.mbqi.max_iterations 15)

; (set-option :auto-config false)
; (set-option :smt.mbqi false)
; (set-option :smt.array.extensional false)

; int extra
(define-fun int_max ((x Int) (y Int)) Int (ite (< x y) y x))
(define-fun int_min ((x Int) (y Int)) Int (ite (< x y) x y))
(define-fun int_abs ((x Int)) Int (ite (< x 0) (- 0 x) x))

; bool to int
(define-fun smt_bool2int ((b Bool)) Int (ite b 1 0))

; ceil32
(define-fun ceil32 ((x Int)) Int ( * ( div ( + x 31 ) 32 ) 32 ) )

;; pow256 and pow255
(define-fun pow256 () Int 115792089237316195423570985008687907853269984665640564039457584007913129639936)
(define-fun pow255 () Int 57896044618658097711785492504343953926634992332820282019728792003956564819968)

;
; end of prelude
;
```
