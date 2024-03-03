{-
 -  Main.hs -- parse command line and run verifier
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

module Main where

import Data.IORef
import Data.Time
import Control.Monad
import System.Console.GetOpt
import System.Environment
import System.Exit
import System.IO

import Alice.Core.Base
import Alice.Core.Verify
import Alice.Data.Instr
import Alice.Data.Text
import Alice.Export.Base
import Alice.Import.Reader

{- and what is the use of a book without pictures or conversation? -}

main :: IO ()
main  =
  do  strt <- getCurrentTime
      hSetBuffering stdout LineBuffering

      cmdl <- readOpts
      cmdf <- readInit (askIS ISinit "init.opt" cmdl)

      let inix = cmdf ++ cmdl
          xini = reverse inix

      text <- readText (askIS ISlibr "." xini) $ map TI inix

      when (askIB IBtext False xini) $ trans strt text

      prdb <- readPrDB (askIS ISprdb "provers.dat" xini)
      rstt <- newIORef (RState [] [] prdb)
      prst <- getCurrentTime

      verify (askIS ISfile "" xini) rstt text

      fint <- getCurrentTime
      stat <- readIORef rstt

      let cntr = rsCntr stat
          igno = cumulCI CIfail 0 cntr
          subt = cumulCI CIsubt 0 cntr
          chkt = cumulCI CIchkt 0 cntr
          prvt = cumulCT CTprov prst cntr

      putStrLn $ "[Main] "
              ++ "sections "    ++ show (cumulCI CIsect 0 cntr)
              ++ " - goals "    ++ show (cumulCI CIgoal 0 cntr)
              ++ (if (igno == 0) then "" else
                 " - failed "   ++ show igno)
              ++ " - subgoals " ++ show (cumulCI CIprov subt cntr)
              ++ " - trivial "  ++ show subt
              ++ " - proved "   ++ show (cumulCI CIprvy 0 cntr)
      putStrLn $ "[Main] "
              ++ "symbols "     ++ show (cumulCI CIsymb 0 cntr)
              ++ " - checks "   ++ show (cumulCI CIchkh chkt cntr)
              ++ " - trivial "  ++ show chkt
              ++ " - proved "   ++ show (cumulCI CIchky 0 cntr)
              ++ " - unfolds "  ++ show (cumulCI CIunfl 0 cntr)
      putStrLn $ "[Main] "
              ++ "parser "      ++ showTimeDiff (diffUTCTime prst strt)
              ++ " - reason "   ++ showTimeDiff (diffUTCTime fint prvt)
              ++ " - prover "   ++ showTimeDiff (diffUTCTime prvt prst)
              ++ "/" ++ showTimeDiff (maximCT CTprvy cntr)
      putStrLn $ "[Main] "
              ++ "total "       ++ showTimeDiff (diffUTCTime fint strt)


trans :: UTCTime -> [Text] -> IO ()
trans strt text = do  mapM_ printTB text ; fint <- getCurrentTime
                      putStrLn $ "[Main] total " ++ tmdiff fint
                      exitWith ExitSuccess
  where
    tmdiff fint = showTimeDiff (diffUTCTime fint strt)
    printTB (TB bl) = print bl ; printTB _ = return ()


-- Command line parsing

readOpts :: IO [Instr]
readOpts  =
  do  (is, fs, es) <- liftM (getOpt Permute options) getArgs
      let text = is ++ [InStr ISfile $ head $ fs ++ [""]]
      unless (all wf is && null es) $ die es
      when (askIB IBhelp False is) helper
      return text
  where
    header  = "Usage: alice <options...> <file>"

    options =
      [ Option "h" [] (NoArg (InBin IBhelp True)) "this help",
        Option ""  ["init"] (ReqArg (InStr ISinit) "FILE")
            "init file, empty to skip (def: init.opt)",
        Option "T" [] (NoArg (InBin IBtext True))
            "translate input text and exit",
        Option ""  ["library"] (ReqArg (InStr ISlibr) "DIR")
            "place to look for library texts (def: .)",
        Option ""  ["provers"] (ReqArg (InStr ISprdb) "FILE")
            "index of provers (def: provers.dat)",
        Option "P" ["prover"] (ReqArg (InStr ISprvr) "NAME")
            "use prover NAME (def: first listed)",
        Option "t" ["timelimit"] (ReqArg (InInt IItlim . number) "N")
            "N seconds per prover call (def: 3)",
        Option ""  ["depthlimit"] (ReqArg (InInt IIdpth . number) "N")
            "N reasoner loops per goal (def: 7)",
        Option ""  ["checktime"] (ReqArg (InInt IIchtl . number) "N")
            "timelimit for checker's tasks (def: 1)",
        Option ""  ["checkdepth"] (ReqArg (InInt IIchdp . number) "N")
            "depthlimit for checker's tasks (def: 3)",
        Option "n" [] (NoArg (InBin IBprov False))
            "cursory mode (equivalent to --prove off)",
        Option "r" [] (NoArg (InBin IBchck False))
            "raw mode (equivalent to --check off)",
        Option "" ["prove"] (ReqArg (InBin IBprov . binary) "{on|off}")
            "prove goals in the text (def: on)",
        Option "" ["check"] (ReqArg (InBin IBchck . binary) "{on|off}")
            "check symbols for definedness (def: on)",
        Option "" ["symsign"] (ReqArg (InBin IBsign . binary) "{on|off}")
            "prevent ill-typed unification (def: on)",
        Option "" ["info"] (ReqArg (InBin IBinfo . binary) "{on|off}")
            "collect \"evidence\" literals (def: on)",
        Option "" ["thesis"] (ReqArg (InBin IBthes . binary) "{on|off}")
            "maintain current thesis (def: on)",
        Option "" ["filter"] (ReqArg (InBin IBfilt . binary) "{on|off}")
            "filter prover tasks (def: on)",
        Option "" ["skipfail"] (ReqArg (InBin IBskip . binary) "{on|off}")
            "ignore failed goals (def: off)",
        Option "" ["flat"] (ReqArg (InBin IBflat . binary) "{on|off}")
            "do not read proofs (def: off)",
        Option "q" [] (NoArg (InBin IBverb False))
            "print no details",
        Option "v" [] (NoArg (InBin IBverb True))
            "print more details (-vv, -vvv, etc)",
        Option "" ["printgoal"] (ReqArg (InBin IBPgls . binary) "{on|off}")
            "print current goal (def: on)",
        Option "" ["printreason"] (ReqArg (InBin IBPrsn . binary) "{on|off}")
            "print reasoner's messages (def: off)",
        Option "" ["printsection"] (ReqArg (InBin IBPsct . binary) "{on|off}")
            "print sentence translations (def: off)",
        Option "" ["printcheck"] (ReqArg (InBin IBPchk . binary) "{on|off}")
            "print checker's messages (def: off)",
        Option "" ["printprover"] (ReqArg (InBin IBPprv . binary) "{on|off}")
            "print prover's messages (def: off)",
        Option "" ["printunfold"] (ReqArg (InBin IBPunf . binary) "{on|off}")
            "print definition unfoldings (def: off)",
        Option "" ["printfulltask"] (ReqArg (InBin IBPtsk . binary) "{on|off}")
            "print full prover tasks (def: off)" ]

    binary "yes"  = True
    binary "on"   = True
    binary "no"   = False
    binary "off"  = False
    binary s      = error $ "invalid boolean argument: " ++ s

    number s  = case reads s of
      ((n,[]):_) | n >= 0 -> n
      _ -> error $ "invalid numeric argument: " ++ s

    wf (InBin _ v)  = v == v
    wf (InInt _ v)  = v == v
    wf _            = True

    helper  = do  putStr $ usageInfo header options
                  exitWith ExitSuccess

    die es  = do  putStr $ concatMap ("[Main] " ++) es
                  exitFailure

