;;; -*- Mode:Lisp; Syntax:ANSI-Common-Lisp; Coding:utf-8; Package:April -*-
;;;; library.lisp

;; this file contains the functions in April's "standard library" that aren't provided
;; by the aplesque package, mostly functions that are specific to the APL language and not
;; generally applicable to array processing

(in-package #:april)

(defun without (omega alpha)
  (flet ((compare (o a)
	   (funcall (if (and (characterp a) (characterp o))
			#'char= (if (and (numberp a) (numberp o))
				    #'= (error "Compared incompatible types.")))
		    o a)))
    (let ((included)
	  (omega-vector (if (or (vectorp omega)
				(not (arrayp omega)))
			    (disclose omega)
			    (make-array (list (array-total-size omega))
					:element-type (element-type omega)
					:displaced-to omega))))
      (loop :for element :across alpha
	 :do (let ((include t))
	       (if (vectorp omega-vector)
		   (loop :for ex :across omega-vector
		      :do (if (compare ex element) (setq include nil)))
		   (if (compare omega-vector element) (setq include nil)))
	       (if include (setq included (cons element included)))))
      (make-array (list (length included))
		  :element-type (element-type alpha)
		  :initial-contents (reverse included)))))

(defun count-to (index index-origin)
  "Implementation of APL's ⍳ function."
  (if (not (integerp index))
      (error "The argument to ⍳ must be a single integer, i.e. ⍳9.")
      (let ((output (make-array (list index) :element-type (list 'integer 0 index))))
	(loop :for ix :below index :do (setf (aref output ix) (+ ix index-origin)))
	output)))

(defun shape (omega)
  (if (or (not (arrayp omega))
	  (= 0 (array-total-size omega)))
      #0A0 (if (vectorp omega)
	       (length omega)
	       (let* ((omega-dims (dims omega))
		      (max-dim (reduce #'max omega-dims)))
		 (make-array (list (length omega-dims))
			     :element-type (list 'integer 0 max-dim)
			     :initial-contents omega-dims)))))

(defun at-index (omega alpha axes index-origin)
  "Find the value(s) at the given index or indices in an array. Used to implement [⌷ index]."
  (if (not (arrayp omega))
      (if (and (numberp alpha)
	       (= index-origin alpha))
	  omega (error "Invalid index."))
      (choose omega (let ((coords (funcall (if (arrayp alpha)
					       #'array-to-list #'list)
					   (apply-scalar #'- alpha index-origin)))
			  ;; the inefficient array-to-list is used here in case of nested
			  ;; alpha arguments like (⊂1 2 3)⌷...
			  (axis (if (first axes) (loop :for item :across (first axes)
						    :collect (- item index-origin)))))
		      (if (not axis)
			  coords (loop :for dim :below (rank omega)
				    :collect (if (member dim axis) (first coords))
				    :when (member dim axis)
				    :do (setq coords (rest coords))))))))

(defun find-depth (omega)
  "Find the depth of an array. Used to implement [≡ depth]."
  (if (not (arrayp omega))
      0 (array-depth omega)))

(defun find-first-dimension (omega)
  "Find the first dimension of an array. Used to implement [≢ first dimension]."
  (if (not (arrayp omega))
      1 (first (dims omega))))

(defun membership (omega alpha)
  (if (not (arrayp alpha))
      (if (not (arrayp omega))
	  (if (funcall (if (eql 'character (element-type alpha))
			   #'char= #'=)
		       omega alpha)
	      1 0)
	  (if (not (loop :for item :across omega :never (funcall (if (eql 'character (element-type alpha))
								     #'char= #'=)
								 item alpha)))
	      1 0))
      (let* ((output (make-array (dims alpha) :element-type 'bit :initial-element 0))
	     (omega (enclose omega))
	     (to-search (make-array (list (array-total-size omega))
				    :displaced-to omega :element-type (element-type omega))))
	;; TODO: this could be faster with use of a hash table and other additions
	(dotimes (index (array-total-size output))
	  (let ((found))
	    (loop :for item :across to-search :while (not found)
	       :do (setq found (or (and (numberp item)
					(numberp (row-major-aref alpha index))
					(= item (row-major-aref alpha index)))
				   (and (characterp item)
					(characterp (row-major-aref alpha index))
					(char= item (row-major-aref alpha index)))
				   (and (arrayp item)
					(arrayp (row-major-aref alpha index))
					(array-compare item (row-major-aref alpha index))))))
	    (if found (setf (row-major-aref output index) 1))))
	output)))

(defun where-equal-to-one (omega index-origin)
  "Return a vector of coordinates from an array where the value is equal to one. Used to implement [⍸ where]."
  (let* ((indices) (match-count 0)
	 (orank (rank omega)))
    (if (= 0 orank)
	(if (= 1 omega)
	    1 0)
	(progn (across omega (lambda (index coords)
			       (if (= 1 index)
				   (let* ((max-coord 0)
					  (coords (mapcar (lambda (i)
							    (setq max-coord
								  (max max-coord (+ i index-origin)))
							    (+ i index-origin))
							  coords)))
				     (incf match-count)
				     (setq indices (cons (if (< 1 orank)
							     (make-array (list orank)
									 :element-type (list 'integer 0 max-coord)
									 :initial-contents coords)
							     (first coords))
							 indices))))))
	       (if (not indices)
		   0 (make-array (list match-count)
				 :element-type (if (< 1 orank)
						   t (list 'integer 0 (reduce #'max indices)))
				 :initial-contents (reverse indices)))))))

(defun tabulate (omega)
  "Return a two-dimensional array of values from an array, promoting or demoting the array if it is of a rank other than two. Used to implement [⍪ table]."
  (if (not (arrayp omega))
      omega (if (vectorp omega)
		(make-array (list (length omega) 1)
			    :element-type (element-type omega)
			    :initial-contents
			    (loop :for i :below (length omega)
			       :collect (list (aref omega i))))
		(let ((o-dims (dims omega)))
		  (make-array (list (first o-dims) (reduce #'* (rest o-dims)))
			      :element-type (element-type omega)
			      :displaced-to (copy-array omega))))))

(defun array-intersection (omega alpha)
  "Return a vector of values common to two arrays. Used to implement [∩ intersection]."
  (let ((omega (enclose omega))
	(alpha (enclose alpha)))
    (if (or (not (vectorp alpha))
	    (not (vectorp omega)))
	(error "Arguments must be vectors.")
	(let* ((match-count 0)
	       (matches (loop :for item :across alpha :when (find item omega :test #'array-compare)
			   :collect item :and :do (incf match-count))))
	  (disclose (make-array (list match-count)
				:initial-contents matches
				:element-type (type-in-common (element-type alpha)
							      (element-type omega))))))))

(defun unique (omega)
  "Return a vector of unique values in an array. Used to implement [∪ unique]."
  (if (not (arrayp omega))
      omega (let ((vector (if (vectorp omega)
			      omega (re-enclose omega (make-array (list (1- (rank omega)))
								  :element-type 'fixnum
								  :initial-contents
								  (loop :for i :from 1 :to (1- (rank omega))
								     :collect i))))))
	      (let ((uniques) (unique-count 0))
		(loop :for item :across vector :when (not (find item uniques :test #'array-compare))
		   :do (setq uniques (cons item uniques))
		   (incf unique-count))
		(funcall (if (vectorp omega)
			     #'identity (lambda (output) (mix-arrays 1 output)))
			 (make-array (list unique-count) :element-type (element-type vector)
				     :initial-contents (reverse uniques)))))))

(defun array-union (omega alpha)
  "Return a vector of unique values from two arrays. Used to implement [∪ union]."
  (let ((omega (enclose omega))
	(alpha (enclose alpha)))
    (if (or (not (vectorp alpha))
	    (not (vectorp omega)))
	(error "Arguments must be vectors.")
	(let* ((unique-count 0)
	       (uniques (loop :for item :across omega :when (not (find item alpha :test #'array-compare))
			   :collect item :and :do (incf unique-count))))
	  (catenate alpha (make-array (list unique-count) :initial-contents uniques
				      :element-type (type-in-common (element-type alpha)
								    (element-type omega)))
		    0)))))

(defun encode (omega alpha)
  "Encode a number or array of numbers as per a given set of bases. Used to implement [⊤ encode]."
  (let* ((omega (if (arrayp omega)
		    omega (enclose omega)))
	 (alpha (if (arrayp alpha)
		    alpha (enclose alpha)))
	 (odims (dims omega)) (adims (dims alpha))
	 (last-adim (first (last adims)))
	 (output (make-array (or (append (loop :for dim :in adims :when (< 1 dim) :collect dim)
					 (loop :for dim :in odims :when (< 1 dim) :collect dim))
				 '(1)))))
    (flet ((rebase (base-coords number)
	     (let ((operand number) (last-base 1)
		   (base 1) (component 1) (element 0))
	       (loop :for index :from (1- last-adim) :downto (first (last base-coords))
		  :do (setq last-base base
			    base (* base (apply #'aref alpha (append (butlast base-coords 1)
								     (list index))))
			    component (if (= 0 base)
					  operand (* base (nth-value 1 (floor (/ operand base)))))
			    operand (- operand component)
			    element (/ component last-base)))
	       element)))
      (across alpha (lambda (aelem acoords)
		      (declare (ignore aelem))
		      (let ((ac (loop :for dx :below (length acoords) :when (< 1 (nth dx adims))
				   :collect (nth dx acoords))))
			(across omega (lambda (oelem ocoords)
					(let ((out-coords (or (append ac (loop :for dx :below (length ocoords)
									    :when (< 1 (nth dx odims))
									    :collect (nth dx ocoords)))
							      '(0))))
					  (setf (apply #'aref output out-coords)
						(rebase acoords oelem))))))))
      (if (is-unitary output)
	  (disclose output)
	  (each-scalar t output)))))

(defun decode (omega alpha)
  "Decode an array of numbers as per a given set of bases. Used to implement [⊥ decode]."
  (let* ((omega (if (arrayp omega)
		    omega (enclose omega)))
	 (alpha (if (arrayp alpha)
		    alpha (enclose alpha)))
	 (odims (dims omega)) (adims (dims alpha))
	 (last-adim (first (last adims)))
	 (output (make-array (or (append (butlast adims 1)
					 (rest odims))
				 '(1)))))
    (flet ((rebase (base-coords number-coords)
	     (let ((base 1) (result 0))
	       (if (and (not (is-unitary base-coords))
			(not (is-unitary number-coords))
			(/= (first odims) (first (last adims))))
		   (error (concatenate 'string "If neither argument to ⊥ is scalar, the first dimension"
				       " of the left argument must equal the first "
				       "dimension of the right argument."))
		   (loop :for index :from (if (< 1 last-adim)
					      (1- last-adim) (1- (first odims)))
		      :downto 0
		      :do (incf result (* base (apply #'aref omega (cons (if (< 1 (first odims))
									     index 0)
									 (rest number-coords)))))
		      (setq base (* base (apply #'aref alpha (append (butlast base-coords 1)
								     (list (if (< 1 last-adim)
									       index 0))))))))
	       result)))
      (across alpha (lambda (aelem acoords)
		      (declare (ignore aelem))
		      (across omega (lambda (oelem ocoords)
				      (declare (ignore oelem))
				      (setf (apply #'aref output (or (append (butlast acoords 1)
									     (rest ocoords))
								     '(0)))
					    (rebase acoords ocoords)))
			      :elements (loop :for i :below (rank omega) :collect (if (= i 0) 0)))))
      :elements (loop :for i :below (rank alpha) :collect (if (= i (1- (rank alpha))) 0)))
    (if (is-unitary output)
	(disclose output)
	(each-scalar t output))))

(defun left-invert-matrix (in-matrix)
  "Perform left inversion of matrix. Used to implement [⌹ matrix inverse]."
  (let* ((input (if (= 2 (rank in-matrix))
		    in-matrix (make-array (list (length in-matrix) 1)
					  :element-type (element-type in-matrix)
					  :initial-contents (loop :for i :across in-matrix :collect (list i)))))
	 (result (array-inner-product
		  (invert-matrix (array-inner-product (aops:permute (reverse (iota (rank input)))
								    input)
						      input (lambda (arg1 arg2) (apply-scalar #'* arg1 arg2))
						      #'+))
		  (aops:permute (reverse (iota (rank input)))
				input)
		  (lambda (arg1 arg2) (apply-scalar #'* arg1 arg2))
		  #'+)))
    (if (= 1 (rank in-matrix))
	(aref (aops:split result 1) 0)
	result)))

(defmacro apply-reducing (operation-symbol operation axes &optional first-axis)
  (let ((omega (gensym)) (o (gensym)) (a (gensym)))
    `(lambda (,omega)
       (disclose-atom (do-over ,omega (lambda (,o ,a) (apl-call ,operation-symbol ,operation ,a ,o))
			       ,(if axes `(- ,(first axes) index-origin)
				    (if first-axis 0 `(1- (rank ,omega))))
			       :reduce t :in-reverse t)))))

(defmacro apply-scanning (operation-symbol operation axes &optional first-axis)
  (let ((omega (gensym)) (o (gensym)) (a (gensym)))
    `(lambda (,omega)
       (do-over ,omega (lambda (,o ,a) (apl-call ,operation-symbol ,operation ,o ,a))
		,(if axes `(- ,(first axes) index-origin)
		     (if first-axis 0 `(1- (rank ,omega))))))))

(defmacro apply-to-each (symbol operation-mondaic operation-dyadic)
  (let ((index (gensym)) (item (gensym)) (omega (gensym)) (alpha (gensym))
	(a (gensym)) (o (gensym)))
    (flet ((expand-dyadic (a1 a2 &optional reverse)
	     (let ((call (if reverse `(apl-call ,symbol ,operation-dyadic
						(enclose (aref ,a1 ,index)) ,a2)
			     `(apl-call ,symbol ,operation-dyadic ,a2
					(enclose (aref ,a1 ,index))))))
	       `(make-array (dims ,a1) :initial-contents (loop :for ,index :below (length ,a1)
							    :collect (each-scalar t ,call))))))
      `(lambda (,omega &optional ,alpha)
	 (declare (ignorable ,alpha))
	 (each-scalar
	  t ,(if (or (not (listp operation-dyadic))
		     (not (listp (second operation-dyadic)))
		     (< 1 (length (second operation-dyadic))))
		 ;; don't create the dyadic clauses if the function being passed is monadic-only
		 `(if ,alpha (cond ((not (arrayp ,omega))
				    ,(expand-dyadic alpha omega))
				   ((not (arrayp ,alpha))
				    ,(expand-dyadic omega alpha t))
				   ((and (vectorp ,omega)
					 (= 1 (length ,omega)))
				    ,(expand-dyadic alpha `(aref ,omega 0)))
				   ((and (vectorp ,alpha)
					 (= 1 (length ,alpha)))
				    ,(expand-dyadic omega `(aref ,alpha 0) t))
				   ((= (length ,alpha) (length ,omega))
				    (aops:each (lambda (,o ,a)
						 (apl-call ,symbol ,operation-dyadic (enclose ,o) (enclose ,a)))
					       ,omega ,alpha))
				   (t (error "Mismatched argument lengths to ¨.")))
		      (aops:each (lambda (,item)
				   (apl-call ,symbol ,operation-mondaic ,item))
				 ,omega))
		 `(aops:each (lambda (,item) (apl-call ,symbol ,operation-mondaic ,item))
			     ,omega)))))))

(defmacro apply-commuting (symbol operation-dyadic)
  (let ((omega (gensym)) (alpha (gensym)))
    `(lambda (,omega &optional ,alpha)
       (apl-call ,symbol ,operation-dyadic (if ,alpha ,alpha ,omega)
		 ,omega))))

(defmacro apply-to-grouped (symbol operation-dyadic)
  (let ((key (gensym)) (keys (gensym)) (key-test (gensym)) (indices-of (gensym))
	(key-table (gensym)) (key-list (gensym)) (item-sets (gensym)) (li (gensym))
	(item (gensym)) (items (gensym)) (vector (gensym)) (coords (gensym))
	(alpha (gensym)) (omega (gensym)))
    `(lambda (,omega &optional ,alpha)
       (let* ((,keys (if ,alpha ,alpha ,omega))
	      (,key-test #'equalp)
	      (,indices-of (lambda (,item ,vector)
			     (loop :for ,li :below (length ,vector)
				:when (funcall ,key-test ,item (aref ,vector ,li))
				:collect (+ index-origin ,li))))
	      (,key-table (make-hash-table :test ,key-test))
	      (,key-list))
	 (across ,keys (lambda (,item ,coords)
			 (if (loop :for ,key :in ,key-list :never (funcall ,key-test ,item ,key))
			     (setq ,key-list (cons ,item ,key-list)))
			 (setf (gethash ,item ,key-table)
			       (cons (apply #'aref (cons ,omega ,coords))
				     (gethash ,item ,key-table)))))
	 (let* ((,item-sets (loop :for ,key :in (reverse ,key-list)
			       :collect (apl-call ,symbol ,operation-dyadic
						  (let ((,items (if ,alpha (gethash ,key ,key-table)
								    (funcall ,indices-of
									     ,key ,keys))))
						    (funcall (if (= 1 (length ,items))
								 #'vector #'identity)
							     (make-array (list (length ,items))
									 :initial-contents
									 (reverse ,items))))
						  ,key))))
	   (mix-arrays 1 (apply #'vector ,item-sets)))))))

(defmacro apply-producing-inner (right-symbol right-operation left-symbol left-operation)
  (let* ((op-right `(lambda (alpha omega) (apl-call ,right-symbol ,right-operation omega alpha)))
	 (op-left `(lambda (alpha omega) (apl-call ,left-symbol ,left-operation omega alpha)))
	 (result (gensym)) (arg1 (gensym)) (arg2 (gensym)) (alpha (gensym)) (omega (gensym)))
    `(lambda (,omega ,alpha)
       (if (and (not (arrayp ,omega))
		(not (arrayp ,alpha)))
	   (funcall (lambda (,result)
		      (if (not (and (arrayp ,result)
				    (< 1 (rank ,result))))
			  ,result (vector ,result)))
		    ;; enclose the result in a vector if its rank is > 1
		    ;; to preserve the rank of the result
		    (reduce ,op-left (aops:each (lambda (e) (aops:each #'disclose e))
						(apply-scalar ,op-right ,alpha ,omega))))
	   (funcall (lambda (result)
		      (if (not (and (= 1 (array-total-size result))
				    (not (arrayp (row-major-aref result 0)))))
			  result (row-major-aref result 0)))
		    (each-scalar t (array-inner-product (if (arrayp ,alpha)
							    ,alpha (vector ,alpha))
							(if (arrayp ,omega)
							    ,omega (vector ,omega))
							(lambda (,arg1 ,arg2)
							  (if (or (arrayp ,arg1) (arrayp ,arg2))
							      (apply-scalar ,op-right ,arg1 ,arg2)
							      (funcall ,op-right ,arg1 ,arg2)))
							,op-left)))))))

(defmacro apply-producing-outer (right-symbol right-operation)
  (let* ((op-right `(lambda (alpha omega) (apl-call ,right-symbol ,right-operation omega alpha)))
	 (inverse (gensym)) (element (gensym)) (alpha (gensym)) (omega (gensym)) (a (gensym)) (o (gensym))
	 (placeholder (gensym)))
    `(lambda (,omega ,alpha)
	   (if (is-unitary ,omega)
	       (if (is-unitary ,alpha)
		   (apl-call :fn ,op-right ,alpha ,omega)
		   (each-scalar t (aops:each (lambda (,element)
					       (let ((,a ,element)
						     (,o (disclose-unitary-array (disclose ,omega))))
						 (apl-call :fn ,op-right ,a ,o)))
					     ,alpha)))
	       (let ((,inverse (aops:outer (lambda (,o ,a)
					     (let ((,o (if (arrayp ,o) ,o (vector ,o)))
						   (,a (if (arrayp ,a) ,a (vector ,a))))
					       ',right-operation
					       (if (is-unitary ,o)
						   ;; swap arguments in case of a
						   ;; unitary omega argument
						   (let ((,placeholder ,a))
						     (setq ,a ,o
							   ,o ,placeholder)))
					       (each-scalar t (funcall
							       ;; disclose the output of
							       ;; user-created functions; otherwise
							       ;; fn←{⍺×⍵+1}
							       ;; 1 2 3∘.fn 4 5 6 (for example)
							       ;; will fail
							       ,(if (or (symbolp right-operation)
									(and (listp right-operation)
									     (eq 'scalar-function
										 (first right-operation))))
								    '#'disclose '#'identity)
							       (apl-call :fn ,op-right ,a ,o)))))
					   ,alpha ,omega)))
		 (each-scalar t (if (not (is-unitary ,alpha))
				    ,inverse (aops:permute (reverse (alexandria:iota
								     (rank ,inverse)))
							   ,inverse))))))))

(defmacro apply-composed (right-symbol right-value right-function-monadic right-function-dyadic
			    left-symbol left-value left-function-monadic left-function-dyadic is-confirmed-monadic)
  (let* ((alpha (gensym)) (omega (gensym)) (processed (gensym))
	 (fn-right (or right-function-monadic right-function-dyadic))
	 (fn-left (or left-function-monadic left-function-dyadic)))
    `(lambda (,omega &optional ,alpha)
       (declare (ignorable ,alpha))
       ,(if (and fn-right fn-left)
	    (let ((clauses (list `(apl-call ,left-symbol ,left-function-dyadic ,processed ,alpha)
				 `(apl-call ,left-symbol ,left-function-monadic ,processed))))
	      `(let ((,processed (apl-call ,right-symbol ,right-function-monadic ,omega)))
		 ,(if is-confirmed-monadic (second clauses)
		      `(if ,alpha ,@clauses))))
	    `(apl-call :fn ,(or right-function-dyadic left-function-dyadic)
		       ,(if (not fn-right) right-value omega)
		       ,(if (not fn-left) left-value omega))))))

(defmacro apply-at-rank (right-value left-symbol left-function-monadic left-function-dyadic)
  (let ((rank (gensym)) (orank (gensym)) (arank (gensym)) (fn (gensym))
	(romega (gensym)) (ralpha (gensym)) (alpha (gensym)) (omega (gensym))
	(o (gensym)) (a (gensym)) (r (gensym)))
    `(lambda (,omega &optional ,alpha)
       (let* ((,rank (disclose ,right-value))
	      (,orank (rank ,omega))
	      (,arank (rank ,alpha))
	      (,fn (if (not ,alpha)
		       (lambda (,o) (apl-call ,left-symbol ,left-function-monadic ,o))
		       (lambda (,o ,a) (apl-call ,left-symbol ,left-function-dyadic ,o ,a))))
	      (,romega (if (and ,omega (< ,rank ,orank))
			   (re-enclose ,omega (each (lambda (,r) (- ,r index-origin))
						    (make-array (list ,rank)
								:initial-contents
								(nthcdr (- ,orank ,rank)
									(iota ,orank :start index-origin)))))))
	      (,ralpha (if (and ,alpha (< ,rank ,arank))
			   (re-enclose ,alpha (each (lambda (,r) (- ,r index-origin))
						    (make-array (list ,rank)
								:initial-contents
								(nthcdr (- ,arank ,rank)
									(iota ,arank :start index-origin))))))))
	 (if ,alpha (merge-arrays (if ,romega (if ,ralpha (each ,fn ,romega ,ralpha)
						  (each ,fn ,romega
							(make-array (dims ,romega)
								    :initial-element ,alpha)))
				      (if ,ralpha (each ,fn (make-array (dims ,ralpha)
									:initial-element ,omega)
							,ralpha)
					  (funcall ,fn ,omega ,alpha))))
	     (if ,romega (merge-arrays (each ,fn ,romega))
		 (funcall ,fn ,omega)))))))

(defmacro apply-to-power (op-right sym-left op-left)
  (let ((alpha (gensym)) (omega (gensym)) (arg (gensym)) (index (gensym)))
    `(lambda (,omega &optional ,alpha)
       (let ((,arg (disclose ,omega)))
	 (loop :for ,index :below (disclose ,op-right)
	    :do (setq ,arg (if ,alpha (apl-call ,sym-left ,op-left ,arg ,alpha)
			       (apl-call ,sym-left ,op-left ,arg))))
	 ,arg))))

(defmacro apply-until (sym-right op-right sym-left op-left)
  (let ((alpha (gensym)) (omega (gensym)) (arg (gensym)) (prior-arg (gensym)))
    `(lambda (,omega &optional ,alpha)
       (declare (ignorable ,alpha))
       (let ((,arg ,omega)
	     (,prior-arg ,omega))
	 (loop :while (= 0 (apl-call ,sym-right ,op-right ,prior-arg ,arg))
	    :do (setq ,prior-arg ,arg
		      ,arg (if ,alpha (apl-call ,sym-left ,op-left ,arg ,alpha)
			       (apl-call ,sym-left ,op-left ,arg))))
	 ,arg))))

(defmacro apply-at (right-symbol right-value right-function-monadic
		    left-symbol left-value left-function-monadic left-function-dyadic)
  (let* ((index (gensym)) (omega-var (gensym)) (output (gensym)) (item (gensym))
	 (coord (gensym)) (coords (gensym)) (result (gensym)) (alen (gensym))
	 (alpha (gensym)) (omega (gensym)))
    (cond (right-function-monadic
	   `(lambda (,omega &optional ,alpha)
	      (declare (ignorable ,alpha))
	      (each-scalar (lambda (,item ,coords)
			     (declare (ignore ,coords))
			     (let ((,result (disclose (apl-call ,right-symbol ,right-function-monadic ,item))))
			       (if (= 1 ,result)
				   (disclose ,(cond ((or left-function-monadic left-function-dyadic)
						     `(if ,alpha (apl-call ,left-symbol ,left-function-dyadic
									   ,item ,alpha)
							  (apl-call ,left-symbol ,left-function-monadic ,item)))
						    (t left-value)))
				   (if (= 0 ,result)
				       ,item (error ,(concatenate 'string "Domain error: A right function operand"
								  " of @ must only return 1 or 0 values."))))))
			   ,omega)))
	  (t `(lambda (,omega)
		(let* ((,omega-var (apply-scalar #'- ,right-value index-origin))
		       (,output (make-array (dims ,omega)))
		       (,coord))
		  ;; make copy of array without type constraint; TODO: is there a more
		  ;; efficient way to do this?
		  (across ,omega (lambda (,item ,coords)
				   (setf (apply #'aref (cons ,output ,coords))
					 ,item)))
		  (loop :for ,index :below (length ,omega-var)
		     :do (setq ,coord (aref ,omega-var ,index))
		     (choose ,output (if (arrayp ,coord)
					 (mapcar #'list (array-to-list ,coord))
					 (list (list ,coord)))
			     :set ,@(cond (left-function-monadic (list left-function-monadic))
					  (t `((if (is-unitary ,left-value)
						   (disclose ,left-value)
						   (lambda (,item ,coords)
						     (declare (ignore ,item))
						     (let ((,alen (if (not (listp ,coord))
								      1 (length ,coord))))
						       (choose ,left-value
							       (mapcar #'list (append (list ,index)
										      (nthcdr ,alen ,coords)))))))
					       :set-coords t)))))
		  ,output))))))
		
(defmacro apply-stenciled (right-value left-symbol left-function-dyadic)
  (let* ((omega (gensym)) (window-dims (gensym)) (movement (gensym)) (o (gensym)) (a (gensym))
	 (op-left `(lambda (,o ,a) (apl-call ,left-symbol ,left-function-dyadic ,o ,a))))
    `(lambda (,omega)
       (cond ((< 2 (rank ,right-value))
	      (error "The right operand of ⌺ may not have more than 2 dimensions."))
	     ((not ,left-function-dyadic)
	      (error "The left operand of ⌺ must be a function."))
	     (t (let ((,window-dims (if (not (arrayp ,right-value))
					(vector ,right-value)
					(if (= 1 (rank ,right-value))
					    ,right-value (choose ,right-value '(0)))))
		      (,movement (if (not (arrayp ,right-value))
				     (vector 1)
				     (if (= 2 (rank ,right-value))
					 (choose ,right-value '(1))
					 (make-array (list (length ,right-value))
						     :element-type 'fixnum :initial-element 1)))))
		  (merge-arrays (stencil ,omega ,op-left ,window-dims ,movement))))))))
