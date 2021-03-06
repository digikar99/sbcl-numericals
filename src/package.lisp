(defpackage :numericals
  (:import-from :trivial-coerce #:coerce)
  (:export

   #:*multithreaded-threshold*
   #:*array-element-type*
   #:*array-element-type-alist*

   :with-broadcast
   :with-elementwise-operations
   :weop          ; convenient wrapper for with-elementwise-operations
   :with-inline
   :with-array
   :with-arrays*
   :with-constant
   :with-constants
   :maybe-form-not-constant-error
   :def-array
   :array-like-p
   :numericals-array-element-type
   :map-outer
   
   :astype
   #:asarray
   :aref
   :concatenate
   #:array=
   #:zeros
   #:zeros-like
   #:ones
   #:ones-like
   #:rand
   #:rand-like
   :shape
   :transpose

   #:sin
   #:cos
   #:tan
   #:asin
   #:acos
   #:atan
   #:sinh
   #:cosh
   #:tanh
   #:asinh
   #:acosh
   #:atanh

   #:exp
   #:log
   #:expt

   :sqrt

   #:ffloor
   #:fceiling
   #:fround
   #:abs
   #:ftruncate

   #:copy
   #:coerce
   #:concat
   #:matmul
   #:two-arg-matmul
   #:dot
   #:sum
   #:shape

   #:+
   #:two-arg-+
   #:*
   #:two-arg-*
   #:-
   #:two-arg--
   #:/
   #:two-arg-/

   #:<
   #:two-arg-<
   #:<=
   #:two-arg-<=
   #:=
   #:two-arg-=
   #:/=
   #:two-arg-/=
   #:>
   #:two-arg->
   #:>=
   #:two-arg->=))

(uiop:define-package :numericals.internals
    (:mix :cl :alexandria :iterate :introspect-environment
          :polymorphic-functions)
  (:import-from :numericals
                #:maybe-form-not-constant-error
                #:*type*
                #:*lookup-type-at-compile-time*)
  (:import-from :polymorphic-functions
                #:optim-speed
                #:env))


(cl:in-package :numericals.internals)
#+sbcl
`(declaim (sb-ext:maybe-inline
           ,@(iter (for s in-package :numericals external-only t)
                   (collect s))))

(trivial-package-local-nicknames:add-package-local-nickname :nu :numericals)

