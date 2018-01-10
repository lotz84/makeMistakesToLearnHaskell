{-# OPTIONS_GHC -Wno-unused-imports #-}

module Education.MakeThemToLearnHaskell.Diagnosis
  ( diagnoseErrorMessage
  ) where


#include <imports/external.hs>

import           Education.MakeThemToLearnHaskell.Evaluator.Types
import           Education.MakeThemToLearnHaskell.Exercise.Types

import           Debug.Trace


diagnoseErrorMessage :: ErrorMessage -> Details
diagnoseErrorMessage =
  f . TextEncoding.decodeUtf8
  where
    f msg =
      if msg `Text.isInfixOf` "Variable not in scope: main :: IO a0"
        then "HINT: This error indicates you haven't defined main function."
        else msg