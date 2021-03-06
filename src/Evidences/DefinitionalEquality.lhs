
\section{Definitional Equality}

%if False

> {-# OPTIONS_GHC -F -pgmF she #-}
> {-# LANGUAGE TypeOperators, GADTs, KindSignatures, RankNTypes,
>     MultiParamTypeClasses, TypeSynonymInstances, FlexibleInstances,
>     FlexibleContexts, ScopedTypeVariables, TypeFamilies #-}

> module Evidences.DefinitionalEquality where

> import Prelude hiding (foldl, exp, compare)
> import ShePrelude

> import Control.Applicative
> import Control.Monad.Error
> import qualified Data.Monoid as M
> import Data.Foldable as F
> import Data.List hiding (foldl)
> import Data.Traversable

> import Kit.MissingLibrary
> import Kit.BwdFwd
> import Kit.NatFinVec

> import Evidences.Tm
> import Evidences.Primitives
> import Evidences.EtaQuote

%endif

> equal :: Int -> (TY :>: (EXP,EXP)) -> Bool
> equal l (t :>: (x, y)) = 
>     compare {Z} (etaQuote l (t :>: x)) (etaQuote l (t :>: y))



> compare :: forall p s . pi (n :: Nat) . Tm {p, s, n} -> Tm {p, s, n} -> Bool
> compare {n} (LK b1)        (LK b2)        = compare {n} b1 b2
> compare {n} (L ENil _ b1)  (L ENil _ b2)  = compare {S n} b1 b2
> compare {n} (CHKD _)       (CHKD _)       = True
> compare {n} (c1 :- es1)    (c2 :- es2)    = 
>   c1 == c2 && maybe False id (| (F.all (uncurry (compare {n}))) (halfZip es1 es2) |)
> compare {n} (h1 :$ es1)    (h2 :$ es2)    = 
>   compare {n} h1 h2 && 
>   maybe False id (| (F.all (uncurry (compareE {n}))) (halfZip es1 es2) |)
> compare {n} (D d1)   (D d2)               = d1 == d2 
> compare {n} (B (SIMPLDTY name1 _I1 uDs1)) (B (SIMPLDTY name2 _I2 uDs2)) =
>   name1 == name2 || equal 0 (SET :>: (_I1, _I2)) && equal 0 (wr (def constrsDEF) _I1 :>: (uDs1, uDs2))
> compare {n} (V i)          (V j)          = i == j
> compare {n} (P (i, _, _))  (P (j, _, _))  = i == j
> compare {n} (Coeh coeh1 _S1 _T1 eq1 s1) (Coeh coeh2 _S2 _T2 eq2 s2) = 
>   coeh1 == coeh2 && compare {n} _S1 _S2 && compare {n} _T1 _T2 && compare {n} s1 s2  
> compare {n} x              y              = False

> compareE :: forall p s . pi (n :: Nat) . Elim (Tm {p, s, n}) -> Elim (Tm {p, s, n}) -> Bool
> compareE {n} (A x) (A y)  = compare {n} x y
> compareE {_} Hd    Hd     = True
> compareE {_} Tl    Tl     = True
> compareE {_} Out   Out    = True
> compareE {_} _     _      = False
