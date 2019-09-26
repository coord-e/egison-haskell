{-# LANGUAGE DataKinds                 #-}
{-# LANGUAGE ExistentialQuantification #-}
{-# LANGUAGE GADTs                     #-}
{-# LANGUAGE MultiParamTypeClasses     #-}
{-# LANGUAGE TypeFamilies              #-}
{-# LANGUAGE TypeOperators             #-}

module Control.Egison.Core (
  -- Pattern
  Pattern(..),
  Matcher(..),
  MatchClause(..),
  -- Matching state
  MState(..),
  MAtom(..),
  MList(..),
  -- Heterogeneous list
  HList(..),
  happend,
  (:++:),
  ) where

import           Data.Maybe

---
--- Pattern
---

-- a: the type of the target
-- m: a matcher passed to the pattern
-- ctx: the intermediate pattern-matching result
-- vs: the list of types bound to the pattern variables in the pattern.
data Pattern a m ctx vs where
  Wildcard :: Pattern a m ctx '[]
  PatVar :: String -> Pattern a m ctx '[a]
  AndPat :: Pattern a m ctx vs -> Pattern a m (ctx :++: vs) vs' -> Pattern a m ctx (vs :++: vs')
  OrPat  :: Pattern a m ctx vs -> Pattern a m ctx vs -> Pattern a m ctx vs
  NotPat :: Pattern a m ctx '[] -> Pattern a m ctx '[]
  PredicatePat :: (HList ctx -> a -> Bool) -> Pattern a m ctx '[]
  -- User-defined pattern; pattern is a function that takes a target, an intermediate pattern-matching result, and a matcher and returns a list of lists of matching atoms.
  Pattern :: Matcher m => (HList ctx -> m -> a -> [MList ctx vs]) -> Pattern a m ctx vs

class Matcher a

data MatchClause a m b = forall vs. (Matcher m) => MatchClause (Pattern a m '[] vs) (HList vs -> b)

---
--- Matching state
---

data MState vs where
  MState :: vs ~ (xs :++: ys) => HList xs -> MList xs ys -> MState vs

-- matching atom
-- ctx: intermediate pattern-matching results
-- vs: list of types bound to the pattern variables in the pattern.
data MAtom ctx vs = forall a m. (Matcher m) => MAtom (Pattern a m ctx vs) m a

-- stack of matching atoms
data MList ctx vs where
  MNil :: MList ctx '[]
  MCons :: MAtom ctx xs -> MList (ctx :++: xs) ys -> MList ctx (xs :++: ys)
  MJoin :: MList ctx xs -> MList (ctx :++: xs) ys -> MList ctx (xs :++: ys)

---
--- Heterogeneous list
---

data HList xs where
  HNil :: HList '[]
  HCons :: a -> HList as -> HList (a ': as)

happend :: HList as -> HList bs -> HList (as :++: bs)
happend (HCons x xs) ys = case proof x xs ys of Refl -> HCons x $ happend xs ys
happend HNil ys         = ys

type family as :++: bs :: [*] where
  bs :++: '[] = bs
  '[] :++: bs = bs
  (a ': as) :++: bs = a ': (as :++: bs)

data (a :: [*]) :~: (b :: [*]) where
  Refl :: a :~: a

proof :: a -> HList as -> HList bs -> ((a ': as) :++: bs) :~: (a ': (as :++: bs))
proof _ _ HNil = Refl
proof x xs (HCons y ys) = Refl

