-- | Pattern-matching expressions.

module Control.Egison.Match (
  matchAll,
  match,
  matchAllDFS,
  matchDFS,
  ) where

import           Prelude hiding (mappend)
import           Control.Egison.Core
import           Unsafe.Coerce
import           Data.Type.Equality

-- | @matchAll@ takes a target, a matcher, and a list of match clauses.
-- @matchAll@ collects all the pattern-matching results and returns a list of the results evaluating the body expression for each pattern-matching result.
-- @matchAll@ traverses a search tree for pattern matching in breadth-first order.
matchAll :: (Matcher m a) => a -> m -> [MatchClause a m b] -> [b]
matchAll tgt m [] = []
matchAll tgt m ((MatchClause pat f):cs) =
  let results = processMStatesAll [[MState HNil (MCons (MAtom pat m tgt) MNil)]] in
  map f results ++ matchAll tgt m cs

-- | @match@ takes a target, a matcher, and a list of match clauses.
-- @match@ calculates only the first pattern-matching result and returns the results evaluating the body expression for the first pattern-matching result.
-- @match@ traverses a search tree for pattern matching in breadth-first order.
match :: (Matcher m a) => a -> m -> [MatchClause a m b] -> b
match tgt m cs = head $ matchAll tgt m cs

-- | @matchAllDFS@ is much similar to @matchAll@ but traverses a search tree for pattern matching in depth-first order.
matchAllDFS :: (Matcher m a) => a -> m -> [MatchClause a m b] -> [b]
matchAllDFS tgt m [] = []
matchAllDFS tgt m ((MatchClause pat f):cs) =
  let results = processMStatesAllDFS [MState HNil (MCons (MAtom pat m tgt) MNil)] in
  map f results ++ matchAllDFS tgt m cs

-- | @matchDFS@ is much similar to @match@ but traverses a search tree for pattern matching in depth-first order.
matchDFS :: (Matcher m a) => a -> m -> [MatchClause a m b] -> b
matchDFS tgt m cs = head $ matchAllDFS tgt m cs

--
-- Pattern-matching algorithm
--

processMStatesAllDFS :: [MState vs] -> [HList vs]
processMStatesAllDFS [] = []
processMStatesAllDFS (MState rs MNil:ms) = rs:(processMStatesAllDFS ms)
processMStatesAllDFS (mstate:ms) = processMStatesAllDFS $ (processMState mstate) ++ ms

processMStatesAll :: [[MState vs]] -> [HList vs]
processMStatesAll [] = []
processMStatesAll streams =
  case extractMatches $ concatMap processMStates streams of
    ([], streams') -> processMStatesAll streams'
    (results, streams') -> results ++ processMStatesAll streams'

extractMatches :: [[MState vs]] -> ([HList vs], [[MState vs]])
extractMatches = extractMatches' ([], [])
 where
   extractMatches' :: ([HList vs], [[MState vs]]) -> [[MState vs]] -> ([HList vs], [[MState vs]])
   extractMatches' (xs, ys) [] = (reverse xs,  reverse ys) -- These calls of the reverse function are very important for performance.
   extractMatches' (xs, ys) ((MState rs MNil:[]):rest) = extractMatches' (rs:xs, ys) rest
   extractMatches' (xs, ys) (stream:rest) = extractMatches' (xs, stream:ys) rest

processMStates :: [MState vs] -> [[MState vs]]
processMStates []          = []
processMStates (mstate:ms) = [processMState mstate, ms]

processMState :: MState vs -> [MState vs]
processMState (MState rs (MCons (MAtom pat m tgt) atoms)) =
  case pat of
    Pattern f ->
      let matomss = f rs m tgt in
      map (\newAtoms -> MState rs (mappend newAtoms atoms)) matomss
    Wildcard -> [MState rs atoms]
    PatVar _ -> case patVarProof rs (HCons tgt HNil) atoms of
                  Refl -> [MState (happend rs (HCons tgt HNil)) atoms]
    AndPat p1 p2 ->
      case (assocProof (MAtom p1 m tgt) (MAtom p2 m tgt)) of
        Refl -> case (andPatProof (MAtom p1 m tgt) (MAtom p2 m tgt) atoms) of
          Refl -> [MState rs (MCons (MAtom p1 m tgt) (MCons (MAtom p2 m tgt) $ atoms))]
    OrPat p1 p2 ->
      [MState rs (MCons (MAtom p1 m tgt) atoms), MState rs (MCons (MAtom p2 m tgt) atoms)]
    NotPat p ->
      [MState rs atoms | null $ processMStatesAll [[MState rs $ MCons (MAtom p m tgt) MNil]]]
    PredicatePat f -> [MState rs atoms | f rs tgt]
processMState (MState rs MNil) = undefined -- or [MState rs MNil] -- TODO: shold not reach here but reaches here.

patVarProof :: HList xs -> HList '[a] -> MList (xs :++: '[a]) ys -> ((xs :++: '[a]) :++: ys) :~: (xs :++: ('[a] :++: ys))
patVarProof HNil _ _ = Refl
patVarProof (HCons _ xs) ys zs = unsafeCoerce Refl -- Todo: Write proof.

andPatProof :: MAtom ctx vs -> MAtom (ctx :++: vs) vs' -> MList (ctx :++: vs :++: vs') ys -> (ctx :++: ((vs :++: vs') :++: ys)) :~: (ctx :++: (vs :++: (vs' :++: ys)))
andPatProof _ _ _ = unsafeCoerce Refl -- Todo: Write proof.

assocProof :: MAtom ctx vs -> MAtom (ctx :++: vs) vs' -> (ctx :++: (vs :++: vs')) :~: ((ctx :++: vs) :++: vs')
assocProof _ _ = unsafeCoerce Refl -- Todo: Write proof.
