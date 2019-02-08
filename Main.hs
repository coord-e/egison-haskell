{-# LANGUAGE QuasiQuotes     #-}
{-# LANGUAGE TemplateHaskell #-}

module Main (main) where

import           Control.Exception.Assert
import           Data.Numbers.Primes
import           Language.Haskell.TH      hiding (match)
import           Match
import           MatchTH
import           MatchTH2
import           Unsafe.Coerce


--
-- Basic list processing functions in pattern-matching-oriented programming style
--

pmMap :: (a -> b) -> [a] -> [b]
pmMap f xs = matchAll xs (list something)
               [(JoinPat Wildcard (ConsPat (PatVar "x") Wildcard),
                \[Result x] -> let x' = unsafeCoerce x in f x')]

pmConcat :: [[a]] -> [a]
pmConcat xss = matchAll xss (multiset (multiset something))
                 $(mc [e| [(ConsPat (ConsPat (PatVar "x") Wildcard) Wildcard, x)] |])

pmUniq :: Eq a => [a] -> [a]
pmUniq xs = matchAll xs (list eql)
              $(mc [e| [(JoinPat (LaterPat (NotPat (JoinPat Wildcard (ConsPat (ValuePat x) Wildcard)))) (ConsPat (PatVar "x") Wildcard), x)] |])


main :: IO ()
main = do
  -- List cons pattern
  let ret = match [1,2,5,9,4] (list integer)
              $(mc [e| [(ConsPat (PatVar "x") (PatVar "xs"), (x, xs))] |])
  assert (ret == (1, [2,5,9,4])) $ print "ok 1"

  -- Multiset cons pattern
  let ret = matchAll [1,2,5,9,4] (multiset integer)
              $(mc [e| [(ConsPat (PatVar "x") (PatVar "xs"), (x, xs))] |])
  assert (ret == [(1,[2,5,9,4]),(2,[1,5,9,4]),(5,[1,2,9,4]),(9,[1,2,5,4]),(4,[1,2,5,9])]) $ print "ok 2"

  -- Twin primes (pattern matching with infinitely many results)
  let ret = matchAll primes (list integer)
              $(mc [e| [(JoinPat Wildcard (ConsPat (PatVar "p") (ConsPat (ValuePat (p + 2)) Wildcard)), (p, p + 2))] |])
  assert (take 10 ret == [(3,5),(5,7),(11,13),(17,19),(29,31),(41,43),(59,61),(71,73),(101,103),(107,109)]) $ print "ok 3"

  -- Value patterns, and-patterns, or-patterns, and not-patterns
  let ret = matchAll [1,2,5,9,4] (multiset integer)
              $(mc [e| [(ConsPat (AndPat (NotPat (ValuePat 5)) (PatVar "x")) (ConsPat (AndPat (OrPat (ValuePat 1) (ValuePat 2)) (PatVar "y")) (PatVar "xs")), (x, y, xs))] |])
  assert (ret == [(1,2,[5,9,4]),(2,1,[5,9,4]),(9,1,[2,5,4]),(9,2,[1,5,4]),(4,1,[2,5,9]),(4,2,[1,5,9])]) $ print "ok 4"

  -- Later pattern
  let ret = match [1..5] (list integer)
              $(mc [e| [(ConsPat (LaterPat (ValuePat $ x - 1)) (ConsPat (PatVar "x") (PatVar "xs")), (x, xs))] |])
  assert (ret == (2,[3,4,5])) $ print "ok 5"

  -- Check the order of pattern-matching results
  let ret = matchAll [1..] (multiset integer)
              $(mc [e| [(ConsPat (PatVar "x") (ConsPat (PatVar "y") Wildcard), (x, y))] |])
  assert (take 10 ret == [(1,2),(1,3),(2,1),(1,4),(2,3),(3,1),(1,5),(2,4),(3,2),(4,1)]) $ print "ok 6"

  -- Predicate patterns
  assert (matchAll [1..10] (multiset integer)
           $(mc [e| [(ConsPat (AndPat (PredicatePat (\x -> mod x 2 == 0)) (PatVar "x")) Wildcard, x :: Integer)] |]) == [2,4,6,8]) $ print "ok 7"

  -- map, concat, uniq
  assert (pmMap (+ 10) [1,2,3] == [11, 12, 13]) $ print "ok map"
  assert (pmConcat [[1,2], [3], [4, 5]] == [1..5]) $ print "ok concat"
  assert (pmUniq [1,1,2,3,2] == [1,2,3]) $ print "ok uniq"

  -- template-haskell
  print (matchAll [1,2,3] (list integer) $(mc [e| [(ConsPat (PatVar "x") (ConsPat (PatVar "y") Wildcard), (x, y) :: (Integer, Integer) )] |]))

  return ()