(in-package :sb-vm)

(eval-when (:compile-toplevel :load-toplevel :execute)

  (defknown (f4-ref) ((simple-array double-float (*))
                      (integer 0 #.most-positive-fixnum))
      (simd-pack-256 double-float)
      (movable foldable flushable always-translatable)
    :overwrite-fndb-silently t)
  (define-vop (f4-ref)
    (:translate f4-ref)
    (:args (v :scs (descriptor-reg))
           (i :scs (any-reg)))
    (:arg-types simple-array-double-float
                tagged-num)
    (:results (dest :scs (double-avx2-reg)))
    (:result-types simd-pack-256-double)
    (:policy :fast-safe)
    (:generator 1
                (inst vmovups
                      dest
                      (make-ea-for-float-ref v i 0 32
                                             :scale (ash 16 (- n-fixnum-tag-bits))))))
  (defknown f4-set ((simple-array double-float (*))
                    (integer 0 #.most-positive-fixnum)
                    (simd-pack-256 double-float))
      (simd-pack-256 double-float)
      (always-translatable)
    :overwrite-fndb-silently t)
  (define-vop (f4-set)
    (:translate f4-set)
    (:args (v :scs (descriptor-reg))
           (i :scs (any-reg))
           (x :scs (double-avx2-reg)))
    (:arg-types simple-array-double-float
                tagged-num
                simd-pack-256-double)
    (:results (result :scs (double-avx2-reg)))
    (:result-types simd-pack-256-double)
    (:policy :fast-safe)
    (:generator 1
                (inst vmovups
                      (make-ea-for-float-ref v i 0 16
                                             :scale (ash 16 (- n-fixnum-tag-bits)))
                      x)
                (move result x))))

(in-package :sbcl-numericals.internals)

;;; What's a better way than macros to take safety into account?
(defmacro f4-ref (vec i)
  (if (zerop (sb-c::policy-quality sb-c::*policy* 'safety))
      ;; this is expected to happen at compile time!
      ;; safety should affect speed by about 5-10%
      `(sb-vm::f4-ref ,vec (* 2 ,i))
      (let ((len (gensym)))
        `(let ((,len (length ,vec)))
           (if (<= (+ (* 4 ,i) 4) ,len)
               (sb-vm::f4-ref ,vec (* 2 ,i))
               (sb-int:invalid-array-index-error ,vec (+ (* 4 ,i) 3) ,len))))))

(defmacro f4-set (vec i new-value)
  (if (zerop (sb-c::policy-quality sb-c::*policy* 'safety))
      `(sb-vm::f4-set ,vec (* 2 ,i) ,new-value)
      (let ((len (gensym)))
        `(let ((,len (length ,vec)))
           (if (<= (+ (* 4 ,i) 4) ,len)
               (sb-vm::f4-set ,vec (* 2 ,i) ,new-value)
               (sb-int:invalid-array-index-error ,vec (+ (* 4 ,i) 3) ,len))))))

(defmacro define-double-vectorized-op (op prefix assembly-equivalent)
  (let  ((sb-vm-symbol (intern (concatenate 'string "%F4" (symbol-name op))
                               :sbcl-numericals.internals))
         (internals-symbol (intern (concatenate 'string "F4" (symbol-name op))
                                   :sbcl-numericals.internals))
         (sbcl-numericals-symbol (find-symbol (concatenate 'string
                                                           (symbol-name prefix)
                                                           (symbol-name op))
                                              :sbcl-numericals)))
    `(progn
       (eval-when (:compile-toplevel :load-toplevel :execute)
         (defknown (,sb-vm-symbol)
             ((simd-pack-256 double-float) (simd-pack-256 double-float))
             (simd-pack-256 double-float)
             (movable flushable always-translatable)
           :overwrite-fndb-silently t)
         (define-vop (,sb-vm-symbol)
           (:translate ,sb-vm-symbol)
           (:policy :fast-safe)
           (:args (x :scs (sb-vm::double-avx2-reg))
                  (y :scs (sb-vm::double-avx2-reg)))
           (:arg-types sb-vm::simd-pack-256-double
                       sb-vm::simd-pack-256-double)
           (:results (r :scs (sb-vm::double-avx2-reg)))
           (:result-types sb-kernel:simd-pack-256-double)
           (:generator 1 ;; what should be the cost?
                       (sb-vm::inst ,assembly-equivalent r x y))))
       (declaim (inline ,internals-symbol))
       (defun ,internals-symbol (simd-256-a simd-256-b)
         (declare (optimize (speed 3)))
         (,sb-vm-symbol simd-256-a simd-256-b))
       (defun ,sbcl-numericals-symbol (array-a array-b result-array)
         (declare (optimize (speed 3) (safety 3))
                  (type (simple-array double-float) array-a array-b result-array))
         (if (not (and (equalp (array-dimensions array-a) (array-dimensions array-b))
                       (equalp (array-dimensions array-a) (array-dimensions result-array))))
             (error "Arrays cannot have different dimensions!"))
         (let ((vec-a (array-storage-vector array-a))
               (vec-b (array-storage-vector array-b))
               (vec-r (array-storage-vector result-array)))
           (loop for i below (floor (length vec-a) 4)                
              do (f4-set vec-r i (,internals-symbol (f4-ref vec-a i)
                                                    (f4-ref vec-b i)))
              finally
                (progn
                  (loop for j from (* 4 (1- i)) below (length vec-a)
                     do 
                       (setf (aref vec-r j)
                             (,op (aref vec-a j)
                                  (aref vec-b j))))
                  (return result-array))))))))

(define-double-vectorized-op - d vsubpd)
(define-double-vectorized-op + d vaddpd)
(define-double-vectorized-op * d vmulpd)
(define-double-vectorized-op / d vdivpd)

;; (defun map-array (function arr-a arr-b arr-c)
;;   (declare (optimize (speed 3))
;;            (type (simple-array double-float) arr-a arr-b))
;;   (flet ((map-simd-256-double (simd-256-a simd-256-b)
;;            (apply '%make-simd-pack-256-double
;;                   (mapcar function
;;                           (multiple-value-list (%simd-pack-256-doubles simd-256-a))
;;                           (multiple-value-list (%simd-pack-256-doubles simd-256-a))))))
;;     (let ((vec-a (array-storage-vector arr-a))
;;           (vec-b (array-storage-vector arr-b))
;;           (vec-c (array-storage-vector arr-c)))
;;       ;; (map 'vector λ(+ - --) vec-a vec-b)
;;       (loop for i below (ceiling (length vec-a) 4)
;;          do (setf (f4-ref vec-c i)
;;                   (map-simd-256-double (f4-ref vec-a i)
;;                                        (f4-ref vec-b i)))
;;          finally (return arr-c)))))

;; (defun map-array (function arr-a arr-b arr-c)
;;   (declare (optimize (speed 3))
;;            (type (simple-array double-float) arr-a arr-b))
;;   (let ((vec-a (array-storage-vector arr-a))
;;         (vec-b (array-storage-vector arr-b))
;;         (vec-c (array-storage-vector arr-c)))
;;     ;; (map 'vector λ(+ - --) vec-a vec-b)
;;     (loop for i below (length vec-a)
;;        do (setf (aref vec-c i)
;;                 (aref vec-a i))
;;        finally (return arr-c))))
