;;; -*- Mode:Lisp; Syntax:ANSI-Common-Lisp; Coding:utf-8; Package:April -*-
;;;; game-of-life.lisp

(in-package #:april)

#|
Just for fun, an implementation of an old APL standby - Conway's Game of Life.

Usage:

To create a new playfield of a given -width- and -height-, evaluate:

(life :width -width- :height -height-)

The new field will contain a random arrangement of cells.

For example, (life :width 64 :height 32) creates a field 64 wide by 32 tall.

If a single number is passed as the argument, it will be both the length and width of the field.

Therefore, evaluating (life 50) will create a 50x50 playfield.

To calculate the next generation, just evaluate:

(life)

If no playfield exists, evaluating (life) will create a new 16x16 playfield.

If you'd like to start with a specific playfield, you can do so by passing a third argument containing a binary matrix. For example:

(life :width -10 :height -10 :seed (april "(3 3⍴⍳9)∊1 2 3 4 8"))

This creates a 10x10 playfield with a glider in the lower right corner; that is, a ¯10 ¯10 take of the glider matrix. Passing 10 and 10 instead of -10 and -10 will result in a 10 10 take with the glider shape in the upper left corner.
|#

(let ((life-array nil)
      (life-generation -1)
      (default-dimension 16))
  (defun life (&key width height seed return)
    "Create or update a playfield for Conway's Game of Life."
    (setq life-array (if (or width (not life-array))
                         (progn (setq life-generation -1)
                                (if seed (april-c "↑" seed (vector height width))
                                    (april-c "{⎕IO-⍨?2⍴⍨|⍺ ⍵}" (or width default-dimension)
                                             (or height width default-dimension))))
                         (april-c "{⊃1 ⍵∨.∧3 4=+/,1 0 ¯1∘.⊖1 0 ¯1⌽¨⊂⍵}" life-array)))
    (incf life-generation)
    (if return (values life-array (list :generation life-generation))
        (progn (april-c "{⎕←' ⍬_║▐▀'[⎕IO+(0,(1+⊢/⍴⍵)⍴2)⍪(3,⍵,4)⍪5]}" life-array)
               (list :generation life-generation)))))
