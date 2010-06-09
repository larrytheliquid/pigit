{-
  Epigram demo
  Pierre-Evariste Dagand and Adam Gundry
  SICSA PhD Conference, 9th June 2010

  ./Pig
-}


{-
  Bool is one of the simplest possible data types, with only two constructors.
-}

data Bool := (false : Bool) ; (true : Bool) ;


{-
  Natural numbers are a data type with two constructors: zero is a number, and
  every number has a successor. 
-}

data Nat := (zero : Nat) ; (suc : Nat -> Nat) ;
elab 'zero : Nat ;
make one := 'suc 'zero : Nat ; elab one ;
make two := 'suc ('suc 'zero) : Nat ; elab two ;


{- 
  We can write functions to manipulate this data.
  The addition function, written in a pattern-matching style, looks like this:

    plus : Nat ->   Nat ->  Nat
    plus   zero     n    =  n
    plus   (suc k)  n    =  suc (plus k n)

  This definition is recursive (it refers to itself), so why does it make sense?
  In other words, why does evaluation of |plus k n| terminate? In fact, the
  definition is structurally recursive on the first argument, but the
  pattern-matching style hides this.

  Epigram requires programs to be total: general recursion is not allowed.
  The structural recursion is made explicit by appeal to the induction principle
  for natural numbers, here called Nat.Ind.
-}

let plus (m : Nat)(n : Nat) : Nat ;
<= Nat.Ind m ;
next ;
define plus ('suc k) n := 'suc (plus k n) ;
root ;

{-
  We are also allowed to leave "holes" in programs and fill them in later.
  Notice that we did not define plus for the case when the first argument is
  zero. Watch what happens when we try to evaluate it:
-}

elab plus two two ;

{-
  Some computation is possible, but not all of it! Perhaps we should go back and
  fill in the missing line of the program:
-}

next ;
define plus 'zero    n := n ; 
root ;

{-
  Now we get the result we expect:
-}

elab plus two two ;



{-
  A major benefit of explicitly appealing to an induction principle is that we
  can invent our own, rather than being restricted to structural recursion.
  If we have two numbers x and y, we can eliminate them by comparison, provided we
  say what to do in three cases:
    l - x is less than y
    e - x and y are equal
    g - x is greater than y
-}

let compare (x : Nat)(y : Nat)(P : Nat -> Nat -> Set)(l : (x : Nat)(y : Nat) -> P x (plus x ('suc y)))(e : (x : Nat) -> P x x)(g : (x : Nat)(y : Nat) -> P (plus y ('suc x)) y) : P x y ;
<= Nat.Ind x ;

<= Nat.Ind y ;
define compare 'zero 'zero    P l e g := e 'zero ;
define compare 'zero ('suc k) P l e g := l 'zero k ;

<= Nat.Ind y ;
define compare ('suc j) 'zero P l e g := g j 'zero ;
relabel compare ('suc j) ('suc k) P l e g ;
<= compare j k ;
= l ('suc x^2) y^3 ;
simplify ;
define compare ('suc j) ('suc j) P l e g := e ('suc j) ;
simplify ;
= g x^2 ('suc y^3) ;
prev ;
out ;
root ;


{-
  Now that we have our new induction principle, we can use it just like Nat.Ind.
  We already did this when explaining how to compare two successors. Here's a
  simpler example:
-}

let max (x : Nat)(y : Nat) : Nat ;
<= compare x y ;
= plus x ('suc y) ;
simplify ;
= x ;
simplify ;
= plus y ('suc x) ;
root ;

elab max two one ;
elab max 'zero one ;
elab max 'zero 'zero ;



{-
  The Curry-Howard correspondence is the observation that types correspond to
  mathematical theorems, and a program is a proof of a theorem. We can use this
  to state and prove theorems about our programs.

  For example, we can show that plus is commutative (independent of the order
  of its arguments):
-}

make plus-commutative := ? : :- ((k : Nat)(n : Nat) => plus k n == plus n k) ;

{-
  In fact, thanks to our model of equality we can prove a stronger result,
  which is not true in most other comparable systems: that the function
  |plus| is equal to |flip plus|.
-}

make flip := (\ f k n -> f n k) : (Nat -> Nat -> Nat) -> Nat -> Nat -> Nat ;
make plus-function-commutative := ? : :- (flip plus == plus) ;








{-
  Parameterised types such as lists are fundamental to functional programming.
  A list is either empty (nil) or a value followed by a list (cons).
-}

data List (A : Set) := (nil : List A) ; (cons : A -> List A -> List A) ;

{-
  What happens if we try to write a function to extract the first element of a
  list? There is nothing we can use to fill the hole.
-}

let head (A : Set)(as : List A) : A ;
<= List.Ind A as ;
define head A 'nil := ? ; next ;
define head A ('cons a _) := a ;
root ;


elab head Bool ('cons 'true 'nil) ;
elab head Bool ('cons 'false ('cons 'true 'nil)) ;
elab head Bool 'nil ;





{-
  There are many similar examples that arise in functional programming.
  How can we resolve this problem? Perhaps instead of using lists, we should
  work with vectors: lists indexed by their length. 

  We need a dependent type: the type needs to depend on a value (the length).
  Eventually, Epigram will allow something like this for the type of vectors:

    data Vec (A : Set) (n : Nat) :=
      (vnil : Vec A 'zero) ;
      (vcons : (m : Nat) -> A -> Vec A m -> Vec A ('suc m)) ;

  Note that |n| is an index, not a parameter: it varies depending on which
  constructor you choose.

  Unfortunately the |data| syntax is not yet implemented for indexed data types,
  so we fiddle about behind the scenes to manually build |Vec|.
-}

load DemoVec.pig ;


{-
  Now we can safely define the vector version of head. Since we ask for a vector
  of length at least one, we know we can always return a result.
-}

let vhead (A : Set)(n : Nat)(as : Vec A ('suc n)) : A ;
<= Vec.Ind A ('suc n) as ;
load DemoVecHeadShips.pig ;
define vhead _ _ ('vcons _ a _) := a ;
root ;


elab vhead Bool 'zero ('vcons 'zero 'true 'vnil) ;
elab vhead Bool one ('vcons one 'false ('vcons 'zero 'true 'vnil)) ;




{-
  The vectorised application function takes a vector of functions and a vector
  of arguments, and applies the functions pointwise.
-}

let vapp (A : Set)(B : Set)(n : Nat)(fs : Vec (A -> B) n)(as : Vec A n) : Vec B n ;
<= Vec.Ind (A -> B) n fs ;

<= ship Nat 'zero k x ;
define vapp A B 'zero 'vnil as := 'vnil ;

<= Vec.Ind A k as ;
load DemoVecAppShips.pig ;
define vapp A B ('suc j) ('vcons j f fs) ('vcons j a as) := 'vcons j (f a) (vapp A B j fs as) ;
root ;


make fs := 'vcons one (plus one) ('vcons 'zero (\ m -> m) 'vnil) : Vec (Nat -> Nat) two ;
make as := 'vcons one two ('vcons 'zero one 'vnil) : Vec Nat two ;
elab vapp Nat Nat two fs as ;




{-
  Another dependent type is the type of finite numbers: |Fin n| is the type of
  natural numbers less than |n|. In imaginary syntax, this might be written:

    data Fin (n : Nat) :=
      (fzero : (m : Nat) -> Fin ('suc m)) ;
      (fsuc : (m : Nat) -> Fin m -> Fin ('suc m)) ;
-}

load DemoFin.pig ;

elab 'fzero 'zero              : Fin one ;
elab 'fzero one                : Fin two ;
elab 'fsuc  one ('fzero 'zero) : Fin two ;


{-
  Now that we can represent numbers less than a certain value, we can explain
  how to safely lookup an index in a vector. At runtime, it would not be
  necessary to check array bounds, because out-of-bounds accesses are prevented
  by the type system.
-}

let lookup (A : Set)(n : Nat)(as : Vec A n)(fn : Fin n) : A ;

<= Vec.Ind A n as ;

<= ship Nat 'zero k x ;
define lookup A 'zero 'vnil fn := naughtE (nuffin fn) A	 ;

<= ship Nat ('suc s^4) k x ;
<= Fin.Ind ('suc s^4) fn ;
= xf^2 ;

<= ship Nat ('suc s^3) k^1 x^1 ;
<= ship Nat s^5 s xf ;
= lookup A s^8 xf^1 xf^7 ;
root ;


elab lookup Bool one ('vcons 'zero 'true 'vnil) ('fzero 'zero) ;
elab lookup Bool two ('vcons one 'true ('vcons 'zero 'false 'vnil)) ('fzero one) ;
elab lookup Bool two ('vcons one 'true ('vcons 'zero 'false 'vnil)) ('fsuc one ('fzero 'zero)) ;



{-
  Here ends the demo. If you are feeling brave, go ahead and look at Cat.pig ;-)
-}