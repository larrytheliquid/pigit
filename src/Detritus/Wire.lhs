\section{Wire Service}
\label{sec:Elaboration.Wire}

%if False

> {-# OPTIONS_GHC -F -pgmF she #-}
> {-# LANGUAGE FlexibleInstances, TypeOperators, TypeSynonymInstances,
>              GADTs, RankNTypes, PatternGuards #-}

> module Elaboration.Wire where

> import Control.Applicative
> import Control.Monad

> import Evidences.Tm
> import Evidences.News

> import ProofState.Structure
> import ProofState.ProofContext
> import ProofState.GetSet
> import ProofState.Navigation
> import ProofState.Interface

> import Elaboration.ElabProb

> import Kit.BwdFwd
> import Kit.MissingLibrary

%endif

\subsection{Updating a reference}

Here we describe how to handle updates to references in the proof
state, caused by refinement commands like |give|. The idea is to deal
with updates lazily, to avoid unnecessary traversals of the proof
tree. When |updateRef| is called to announce a changed reference (that
the current development has already processed), it simply inserts a
news bulletin below the current development.

> updateDef :: DEF -> ProofState ()
> updateDef def = putNewsBelow ([(def, GoodNews)], Nothing)


\subsection{Committing news into the ProofState}

If there are no entries to process, we should tell the current entry
(there is one, as we are within a development), stash the bulletin
after the current location and stop. Note that the insertion is
optional because it will fail when we have reached the end of the
module, at which point everyone knows the news anyway.

> startPropagateNews :: NewsyEntries -> ProofState ()
> startPropagateNews es = runPropagateNews NONEWS es

> runPropagateNews :: NewsBulletin -> NewsyEntries -> ProofState ()
> runPropagateNews news es = do
>     news' <- propagateNews news es
>     unless (boring news') $ do
>         news'' <- tellCurrentEntry news'
>         optional (putNewsBelow news'')
>         return ()


The |propagateNews| function takes a current news bulletin and a list
of entries to \emph{add} to the current development. It applies the
news bulletin to each entry in turn, picking up other bulletins along
the way. This function is called when navigating to a development that
may contain news bulletins, so they can be pushed out of sight.

> propagateNews :: NewsBulletin -> NewsyEntries -> 
>                      ProofState NewsBulletin

If we have nothing to say, we might as well give up and go home.

> propagateNews news (NF F0) = return news


To update a parameter, we check to see if its type has become more
defined, and pass on the good news if necessary.

> propagateNews news (NF (Right (EParam k n ty l) :> es)) = do
>     let (e', news') = tellParamEntry news (EParam k n ty l)
>     putEntryAbove e'
>     propagateNews news' (NF es)

To update definitions or modules, we call on |propagateNewsWithin|.

> propagateNews news (NF (Right e :> es)) = do
>     news' <- propagateNewsWithin news e
>     propagateNews news' (NF es)

Finally, if we encounter an older news bulletin when propagating news,
we can simply merge the two together.

> propagateNews news (NF (Left oldNews :> es)) =
>   propagateNews (mergeNews news oldNews) (NF es)


The |propagateNewsWithin| command will:
\begin{enumerate}
\item add the definition to the proof state without its children;
\item recursively propagate the news to the children, adding them as it goes;
\item call |tellCurrentEntry| to update the definition itself; and
\item move the focus out of the definition.
\end{enumerate}

> propagateNewsWithin :: NewsBulletin -> Entry NewsyFwd -> ProofState NewsBulletin
> propagateNewsWithin news e = do
>     putEntryAbove $ modifyEntryDev (\ dev -> dev{devEntries=B0}) e
>     goInHere
>     let Just Dev{devEntries=es} = entryDev e
>     -- Propagate news through children and current entry
>     news'   <- propagateNews news es
>     news''  <- tellCurrentEntry news'
>     -- Go out to where we were before
>     goOut
>     return news''


\subsection{Informing a current entry about its development}

The update of a parameter consists in:
\begin{enumerate}
\item updating its type based on the news we received, and
\item adding to the news bulletin the fact that this parameter has
      been updated
\end{enumerate}

News about the parameter will be appended to the news bulletin, so the
bulletin must contain boy news for all the previous parameters.

> tellParamEntry :: NewsBulletin -> Entry Bwd -> (Entry Bwd, NewsBulletin)
> tellParamEntry (gns, bns) (EParam k n ty l) = 
>     let (ty', ne) = tellNews (gns, bns) ty
>         bns' = case (bns, ne) of
>                  (Just bs, _)      -> Just (bs :< toBoyNews ne ty')
>                  (Nothing, NoNews) -> Nothing
>                  (Nothing, _)      -> Just (noBoyNews l :< toBoyNews ne ty')
>     in (EParam k n ty' l, (gns, bns'))



The |tellCurrentEntry| function informs the current entry about a news
bulletin that her children have already received, and returns the
updated news.

> tellCurrentEntry :: NewsBulletin -> ProofState NewsBulletin
> tellCurrentEntry news = do
>     tip <- getDevTip
>     let (tip', ne) = tellTip news tip
>     case ne of
>         NoNews    -> return news
>         GoodNews  -> do
>             putDevTip tip'
>             (def, _) <- updateDefFromTip
>             return $ addGirlNews (def, GoodNews) news

> tellTip :: NewsBulletin -> Tip -> (Tip, News)
> tellTip _ Module = (Module, NoNews)
> tellTip news (Unknown ty hk) = (Unknown ty' hk, ne)
>   where (ty', ne) = tellNews news ty
> tellTip news (Defined (ty :>: tm)) = (Defined (ty' :>: tm'), ne)
>   where  (ty', ne1) = tellNews news ty
>          (tm', ne2) = tellNews news tm
>          ne         = min ne1 ne2
> tellTip news (Suspended ty ep hk) = (Suspended ty' ep' hk, ne)
>   where  (ty', ne1)  = tellNews news ty
>          (ep', ne2)  = tellEProb news ep
>          ne          = min ne1 ne2


> tellEProb :: NewsBulletin -> EProb -> (EProb, News)
> tellEProb news (ElabDone t) = (ElabDone t', ne)
>   where (t', ne) = tellNews news t
> tellEProb news ElabHope = (ElabHope, NoNews)
> tellEProb news (ElabProb p) = (ElabProb p, NoNews)
> tellEProb news (ElabInferProb p) = (ElabInferProb p, NoNews)
> tellEProb news (WaitCan t ep) = (WaitCan t' ep', ne)
>   where  (t', ne1)   = tellNews news t
>          (ep', ne2)  = tellEProb news ep
>          ne          = min ne1 ne2
> tellEProb news (WaitSolve d t ep) = (WaitSolve d' t' ep', ne)
>   where  (d', ne1)    = case getNews news d of
>                            Just dn  -> dn
>                            Nothing  -> (d, NoNews)
>          (t', ne2)    = tellNews news t
>          (ep', ne3)   = tellEProb news ep
>          ne           = min (min ne1 ne2) ne3
> tellEProb news (ElabSchedule ep) = (ElabSchedule ep', ne)
>   where (ep', ne) = tellEProb news ep




The |tellEntry| function informs an entry about a news bulletin that
its development (if any) have already received. It applies the news
bulletin to the entry, returning the update entry together with
(potentially) more news.

\begin{danger}[Invariant: |tellEntry| on a definition]

If the entry is a definition, it must be the current entry of the
current cursor position (i.e. the entry should come from
|getLeaveCurrent|).

\end{danger}

\pierre{There is something fishy with this function and this
invariant. In reality, there are two function, one defined on
Parameters and called only on Parameters (in
@ProofState.Edition.Navigation@) (call it |tellParameterEntry|) and
one defined on Definitions and only called by itself and
|tellCurrentEntry| in a safe wrapper enforcing this invariant (call it
|tellDefinitionEntry|).

If we do the split, on one hand, the invariant will always be
enforced. On the other hand, we get two functions with a partial
pattern-matching. At least, with two explicitly named functions, one
can hardly ignore that one is for Parameters and the other for
Definitions.}

< tellEntry :: NewsBulletin -> Entry Bwd -> ProofState (NewsBulletin, Entry Bwd)

Modules carry no type information, so they are easy:

< tellEntry news (EModule n d) = return (news, EModule n d)

To update a hole, we must first check to see if the news bulletin contains a
definition for it. If so, we fill in the definition (and do not need to
update the news bulletin). If not, we must  \pierre{why?}:
\begin{enumerate}
\item update the tip type;
\item update the overall type of the entry, as stored in the reference; and
\item update the news bulletin with news about this definition.
\end{enumerate}
If the hole is |Hoping| and we have good news about its type, then we
restart elaboration to see if it can make any progress.

< tellEntry news (EDef def dev)  -- ref(name := HOLE h :<: tyv) sn
<                       -- dkind dev(Dev {devTip=Unknown tt}) ty anchor)
<   | Just (ref'@(_ := DEFN tm :<: _), GoodNews) <- getNews news ref = do
<     -- We have a Definition for it
<     es   <- getInScope
<     tm'  <- bquoteHere (tm $$$ paramSpine es)
<     let  (tt', _) = tellNewsEval news tt
<          (ty', _) = tellNews news ty
<     -- Define the hole
<     return (news, EDEF ref' sn dkind (dev{devTip=Defined tm' tt'}) ty' anchor)
<
<   | otherwise = do
<     -- Not a Definition
<     let  (tt', n)             = tellNewsEval news tt
<          (ty' :=>: tyv', n')  = tellNewsEval news (ty :=>: tyv)
<          ref                  = name := HOLE h :<: tyv'
<          tip                  = case (min n n', h) of
<                                  (GoodNews, Hoping)  -> Suspended tt' ElabHope
<                                  _                   -> Unknown tt'
<     return  (addNews (ref, min n n') news,
<             EDEF ref sn dkind (dev{devTip=tip}) ty' anchor)



To update a hole with a suspended elaboration problem attached, we
proceed similarly to the previous case, but we also update the
elaboration problem.  If the news bulletin defines this hole, it had
better just be hoping for a solution \pierre{Is this an invariant we
are meant to enforce? Or something that might break one day? See bug
\#53.}, in which case we can safely ignore the attached |ElabHope|
process.



< tellEntry news (EDEF  ref@(name := HOLE h :<: tyv) sn
<                       dkind dev@(Dev {devTip=Suspended tt prob}) ty anchor)
<   | Just ne <- getNews news ref = do
<      -- We have a Definition for it
<      case prob of
<       ElabHope  -> do
<         -- The elaboration strategy \emph{has to} be to |Hope|
<         tellEntry news (EDEF ref sn dkind (dev{devTip=Unknown tt}) ty anchor)
<       _         -> do
<         -- \pierre{Is that a |throwError| or an |error|?}
<         throwError' . err . unlines $ [
<                     "tellEntry: news bulletin contains update", show ne,
<                     "for hole", show ref,
<                     "with suspended computation", show prob]
<   | otherwise = do
<     -- We don't have a Definition
<     let  (tt', n)             = tellNewsEval news tt
<          (ty' :=>: tyv', n')  = tellNewsEval news (ty :=>: tyv)
<          ref                  = name := HOLE h :<: tyv'
<          prob'                = tellEProb news prob
<          state                = if isUnstable prob' 
<                                   then SuspendUnstable 
<                                   else SuspendStable
<     suspendHierarchy state
<     return  (addNews (ref, min n n') news,
<             EDEF ref sn dkind (dev{devTip=Suspended tt' prob'}) ty' anchor)
<         where tellEProb :: NewsBulletin -> EProb -> EProb
<               tellEProb news = fmap (getLatest news)



To update a closed definition (|Defined|), we must:
\begin{enumerate}
\item update the tip type;
\item update the overall type of the entry, as stored in the reference;
\item update the definition and re-evaluate it
         (\question{could this be made more efficient?}); and
\item update the news bulletin with news about this definition.
\end{enumerate}

< tellEntry news (EDef def dev@(Dev {devTip=Defined (ty :>: tm)})) = do  
<     let  (ty', ne)   = tellNews news ty 
<          (tm', ne')  = tellNews news tm

<     let def' = def{defTy=dty'}name := DEFN (evTm tmL') :<: tyv'
<     return  (addNews (def', min ne ne') news,
<             EDef def' (dev{devTip=Defined (ty' :>: tm')}))




When the current location or one of its children has suspended, we need to
update the outer layers.

> suspendHierarchy :: SuspendState -> ProofState ()
> suspendHierarchy ss = getLayers >>= putLayers . help ss
>   where
>     help :: SuspendState -> Bwd Layer -> Bwd Layer
>     help ss B0 = B0
>     help ss (ls :< l) = help ss' ls :< l{laySuspendState = ss'}
>       where ss' = min ss (laySuspendState l)


