{-
 -  Data/Kit.hs -- various functions on formulas
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

module Alice.Data.Kit where

import Control.Monad
import Data.Maybe

import Alice.Data.Formula

-- Alpha-beta normalization

albet (Iff f g)       = zIff f g
albet (Imp f g)       = Or (Not f) g
albet (Not (All v f)) = Exi v $ Not f
albet (Not (Exi v f)) = All v $ Not f
albet (Not (Iff f g)) = albet $ Not $ zIff f g
albet (Not (Imp f g)) = And f (Not g)
albet (Not (And f g)) = Or (Not f) (Not g)
albet (Not (Or f g))  = And (Not f) (Not g)
albet (Not (Not f))   = albet f
albet (Not Top)       = Bot
albet (Not Bot)       = Top
albet f               = f

deAnd = spl . albet
  where
    spl (And f g) = deAnd f ++ deAnd g
    spl f = [f]

deOr  = spl . albet
  where
    spl (Or f g)  = deOr f ++ deOr g
    spl f = [f]


-- Boolean simplification

bool (All _ Top)  = Top
bool (All _ Bot)  = Bot
bool (Exi _ Top)  = Top
bool (Exi _ Bot)  = Bot
bool (Iff Top f)  = f
bool (Iff f Top)  = f
bool (Iff Bot f)  = bool $ Not f
bool (Iff f Bot)  = bool $ Not f
bool (Imp Top f)  = f
bool (Imp _ Top)  = Top
bool (Imp Bot _)  = Top
bool (Imp f Bot)  = bool $ Not f
bool (Or  Top _)  = Top
bool (Or  _ Top)  = Top
bool (Or  Bot f)  = f
bool (Or  f Bot)  = f
bool (And Top f)  = f
bool (And f Top)  = f
bool (And Bot _)  = Bot
bool (And _ Bot)  = Bot
bool (Tag _ Top)  = Top
bool (Tag _ Bot)  = Bot
bool (Not Top)    = Bot
bool (Not Bot)    = Top
bool f            = f

neg (Not f) = f
neg f = bool $ Not f


-- Maybe quantification

mbBind v  = dive id
  where
    dive c s (All u f)  = dive (c . bool . All u) s f
    dive c s (Exi u f)  = dive (c . bool . Exi u) s f
    dive c s (Tag a f)  = dive (c . bool . Tag a) s f
    dive c s (Not f)    = dive (c . bool . Not) (not s) f
    dive c False (Imp f g)  = dive (c . bool . (`Imp` g)) True f
                      `mplus` dive (c . bool . (f `Imp`)) False g
    dive c False (Or f g)   = dive (c . bool . (`Or` g)) False f
                      `mplus` dive (c . bool . (f `Or`)) False g
    dive c True (And f g)   = dive (c . bool . (`And` g)) True f
                      `mplus` dive (c . bool . (f `And`)) True g
    dive c True (Trm "=" [l@(Var u _), t] _)
      | u == v && not (occurs l t) && closed t
                = return $ subst t u (c Top)
    dive _ _ _  = mzero

mbExi v f = fromMaybe (zExi v f) (mbBind v True f)
mbAll v f = fromMaybe (zAll v f) (mbBind v False f)


-- Useful macros

zAll v f  = All v $ bind v f
zExi v f  = Exi v $ bind v f

zIff f g  = And (Imp f g) (Imp g f)

zOr (Not f) g = Imp f g
zOr f g       = Or  f g

zVar v    = Var v []
zTrm t ts = Trm t ts []
zThesis   = zTrm "#TH#" []
zEqu t s  = zTrm "=" [t,s]
zSet t    = zTrm "aSet" [t]
zElm t s  = zTrm "aElementOf" [t,s]
zLess t s = zTrm "iLess" [t,s]
zSSS s ts = zTrm ('c':'S':':':s) ts

isTop Top = True
isTop _   = False

isBot Bot = True
isBot _   = False

isIff (Iff _ _) = True
isIff _         = False

isInd (Ind _ _) = True
isInd _         = False

isVar (Var _ _) = True
isVar _         = False

isTrm (Trm _ _ _) = True
isTrm _           = False

isEqu (Trm "=" [_,_] _) = True
isEqu _                 = False

isThesis (Trm "#TH#" [] _)  = True
isThesis _                  = False

isSSS (Trm ('c':'S':':':_) _ _) = True
isSSS _                         = False


-- Holes and slots

zHole = zVar "?"
zSlot = zVar "!"

isHole (Var "?" _)  = True
isHole _            = False

isSlot (Var "!" _)  = True
isSlot _            = False

substH t  = subst t "?"
substS t  = subst t "!"

occursH = occurs zHole
occursS = occurs zSlot


-- Misc stuff

strip (Tag _ f) = strip f
strip (Not f)   = Not $ strip f
strip f         = f

infilt vs v = guard (v `elem` vs) >> return v
nifilt vs v = guard (v `notElem` vs) >> return v

dups (v:vs) = infilt vs v `mplus` dups vs
dups _      = mzero


-- Show instances

instance Show Formula where
  showsPrec p = showFormula p 0

showFormula :: Int -> Int -> Formula -> ShowS
showFormula p d = dive
    where
      dive (All _ f)  = showString "forall " . binder f
      dive (Exi _ f)  = showString "exists " . binder f
      dive (Iff f g)  = showParen True $ sinfix " iff " f g
      dive (Imp f g)  = showParen True $ sinfix " implies " f g
      dive (Or  f g)  = showParen True $ sinfix " or "  f g
      dive (And f g)  = showParen True $ sinfix " and " f g
      dive (Tag a f)  = showParen True $ shows a
                      . showString " :: " . dive f
      dive (Not f)    = showString "not " . dive f
      dive Top        = showString "truth"
      dive Bot        = showString "contradiction"

      dive (Trm "#TH#" _ _)   = showString "thesis"
      dive (Trm "=" [l,r] _)  = sinfix " = " l r
      dive (Trm ('s':s) ts _) = showString (symDecode s) . sargs ts
      dive (Trm ('t':s) ts _) = showString s . sargs ts
      dive (Trm s ts _)       = showString s . sargs ts
      dive (Var ('x':s) _)    = showString s
      dive (Var s _)          = showString s
      dive (Ind i _)  | i < d = showChar 'v' . shows (d - i - 1)
                      | True  = showChar 'v' . showChar '?'

      sargs []  = id
      sargs _   | p == 1  = showString "(...)"
      sargs ts  = showArgs (showFormula (pred p) d) ts

      binder f      = showFormula p (succ d) (Ind 0 []) . showChar ' '
                    . showFormula p (succ d) f

      sinfix o f g  = dive f . showString o . dive g

showArgs sh (t:ts)  = showParen True $ sh t . showTail sh ts
showArgs _ _        = id

showTail sh ts      = foldr ((.) . ((showChar ',' .) . sh)) id ts


-- Symbolic names

symChars    = "`~!@$%^&*()-+=[]{}:'\"<>/?\\|;,"

symEncode s = concatMap chc s
  where
    chc '`' = "bq" ; chc '~'  = "tl" ; chc '!' = "ex"
    chc '@' = "at" ; chc '$'  = "dl" ; chc '%' = "pc"
    chc '^' = "cf" ; chc '&'  = "et" ; chc '*' = "as"
    chc '(' = "lp" ; chc ')'  = "rp" ; chc '-' = "mn"
    chc '+' = "pl" ; chc '='  = "eq" ; chc '[' = "lb"
    chc ']' = "rb" ; chc '{'  = "lc" ; chc '}' = "rc"
    chc ':' = "cl" ; chc '\'' = "qt" ; chc '"' = "dq"
    chc '<' = "ls" ; chc '>'  = "gt" ; chc '/' = "sl"
    chc '?' = "qu" ; chc '\\' = "bs" ; chc '|' = "br"
    chc ';' = "sc" ; chc ','  = "cm" ; chc '.' = "dt"
    chc c   = ['z', c]

symDecode s = sname [] s
  where
    sname ac ('b':'q':cs) = sname ('`':ac) cs
    sname ac ('t':'l':cs) = sname ('~':ac) cs
    sname ac ('e':'x':cs) = sname ('!':ac) cs
    sname ac ('a':'t':cs) = sname ('@':ac) cs
    sname ac ('d':'l':cs) = sname ('$':ac) cs
    sname ac ('p':'c':cs) = sname ('%':ac) cs
    sname ac ('c':'f':cs) = sname ('^':ac) cs
    sname ac ('e':'t':cs) = sname ('&':ac) cs
    sname ac ('a':'s':cs) = sname ('*':ac) cs
    sname ac ('l':'p':cs) = sname ('(':ac) cs
    sname ac ('r':'p':cs) = sname (')':ac) cs
    sname ac ('m':'n':cs) = sname ('-':ac) cs
    sname ac ('p':'l':cs) = sname ('+':ac) cs
    sname ac ('e':'q':cs) = sname ('=':ac) cs
    sname ac ('l':'b':cs) = sname ('[':ac) cs
    sname ac ('r':'b':cs) = sname (']':ac) cs
    sname ac ('l':'c':cs) = sname ('{':ac) cs
    sname ac ('r':'c':cs) = sname ('}':ac) cs
    sname ac ('c':'l':cs) = sname (':':ac) cs
    sname ac ('q':'t':cs) = sname ('\'':ac) cs
    sname ac ('d':'q':cs) = sname ('"':ac) cs
    sname ac ('l':'s':cs) = sname ('<':ac) cs
    sname ac ('g':'t':cs) = sname ('>':ac) cs
    sname ac ('s':'l':cs) = sname ('/':ac) cs
    sname ac ('q':'u':cs) = sname ('?':ac) cs
    sname ac ('b':'s':cs) = sname ('\\':ac) cs
    sname ac ('b':'r':cs) = sname ('|':ac) cs
    sname ac ('s':'c':cs) = sname (';':ac) cs
    sname ac ('c':'m':cs) = sname (',':ac) cs
    sname ac ('d':'t':cs) = sname ('.':ac) cs
    sname ac ('z':c:cs)   = sname (c:ac) cs
    sname ac cs@(':':_)   = reverse ac ++ cs
    sname ac []           = reverse ac
    sname _ _             = s

