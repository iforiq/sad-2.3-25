{-
 -  Core/Thesis.hs -- maintain current proof thesis
 -  Copyright (c) 2001-2008  Andrei Paskevich <atertium@gmail.com>
 -
 -  This file is part of SAD/Alice - a mathematical text verifier.
 -
 -  SAD/Alice is free software; you can redistribute it and/or modify
 -  it under the terms of the GNU General Public License as published by
 -  the Free Software Foundation; either version 3 of the License, or
 -  (at your option) any later version.
 -
 -  SAD/Alice is distributed in the hope that it will be useful,
 -  but WITHOUT ANY WARRANTY; without even the implied warranty of
 -  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 -  GNU General Public License for more details.
 -
 -  You should have received a copy of the GNU General Public License
 -  along with this program.  If not, see <http://www.gnu.org/licenses/>.
 -}

module Alice.Core.Thesis (thesis) where

import Control.Monad
import Data.List
import Data.Maybe

import Alice.Core.Info
import Alice.Core.Extras
import Alice.Data.Formula
import Alice.Data.Kit
import Alice.Data.Text

-- Infer new thesis

thesis :: [Context] -> Context -> (Bool, Context)
thesis cnt@(ct:_) tc = (nmt, ntc)
  where
    nmt = cnSign ct || isJust ith
    ntc = setForm tc $ reduce kth
    kth = tmWipe (tmDown $ cnForm ct) jth
    jth | cnSign ct = ths
        | otherwise = fromMaybe ths ith
    ith = tmInst cnt ths
    ths = cnForm tc


-- Reduce f in sight of hs

tmWipe hs f | any (tmComp 0 $ f) hs     = Top
            | any (tmComp 0 $ Not f) hs = Bot
            | isTrm f                   = f
            | isIff f                   = tmWipe hs $ albet f
            | otherwise                 = bool $ mapF (tmWipe hs) f

tmComp n f g  = cmp (albet f) (albet g)
  where
    cmp (All _ a) (All _ b) = tmComp (succ n) (inst nvr a) (inst nvr b)
    cmp (Exi _ a) (Exi _ b) = tmComp (succ n) (inst nvr a) (inst nvr b)
    cmp (And a b) (And c d) = tmComp n a c && tmComp n b d
    cmp (Or a b) (Or c d)   = tmComp n a c && tmComp n b d
    cmp (Not a) (Not b)     = tmComp n a b
    cmp (Tag _ a) b         = tmComp n a b
    cmp a (Tag _ b)         = tmComp n a b
    cmp Top Top             = True
    cmp Bot Bot             = True
    cmp a b                 = twins a b

    nvr = show n


-- Instantiate f with vs in sight of h

tmInst (ct:cnt) ths = find gut insts
  where
    insts = map snd $ runTM (tmPass ths) $ cnDecl ct
    gut g = isTop $ tmWipe (tmFlat 0 $ Not g) $ cnForm ct

tmFlat n  = flat . albet
  where
    flat (Exi _ f) = tmFlat (succ n) (inst nvr f)
    flat (And g f) = tmDown g ++ tmFlat n f
    flat f         = [f]

    nvr = '.' : show n

tmDown = spl . albet
  where
    spl (And f g) = tmDown f ++ tmDown g
    spl (Not f) | hasInfo f = Not f : concatMap (tmDown . Not) (trInfoD f)
                              ++  concatMap tmDown (trInfoO f)
    spl f | hasInfo f       = f : concatMap tmDown (trInfoD f)
                              ++  concatMap tmDown (trInfoI f)
    spl f = [f]


-- Find possible instantiations

tmPass  = pass [] (Just True) 0
  where
    pass fc sg n  = dive
      where
        dive h@(All u f)    = case sg of
                Just True   -> qua u f `mplus` rnd h
                _           -> return h
        dive h@(Exi u f)    = case sg of
                Just False  -> qua u f `mplus` rnd h
                _           -> return h
        dive h@(Trm _ _ _)  = return h `mplus` dfs h
        dive h              = rnd h

        qua u f = tmVars u f >>= dive
        rnd = roundFM 'z' pass fc sg n
        dfs = msum . map (dive . reduce) . trInfoD

tmVars u f  = TM (vrs [])
  where
    vrs ov (v:vs) | gut u v = (ov ++ vs, inst v f) : vrs (v:ov) vs
                  | True    = vrs (v:ov) vs
    vrs _ _                 = []

    gut x@('x':_) y = x == y
    gut _ _         = True


-- Thesis monad

newtype TM res = TM { runTM :: [String] -> [([String], res)] }

instance Monad TM where
  return r  = TM $ \ s -> [(s, r)]
  m >>= k   = TM $ \ s -> concatMap apply (runTM m s)
    where apply (s, r) = runTM (k r) s

instance MonadPlus TM where
  mzero     = TM $ \ _ -> []
  mplus m k = TM $ \ s -> runTM m s ++ runTM k s

