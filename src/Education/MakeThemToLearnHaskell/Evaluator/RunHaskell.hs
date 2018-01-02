{-# OPTIONS_GHC -Wno-unused-imports #-}

module Education.MakeThemToLearnHaskell.Evaluator.RunHaskell
  ( runFile
  , RunHaskellError(..)
  ) where


#include <imports/external.hs>


import           Education.MakeThemToLearnHaskell.Evaluator.Types


data RunHaskellError =
  RunHaskellNotFound | RunHaskellFailure ErrorCode ErrorMessage deriving (Show, Typeable)

instance Exception RunHaskellError


runFile :: FilePath -> IO (Either RunHaskellError (ByteString, ByteString))
runFile src = do
  cmd <- resolveInterpreter
  case cmd of
      [] -> return $ Left RunHaskellNotFound
      (h:left) -> do
        -- TODO: -fdiagnostics-color=always
        (ecode, out, err) <- readProcess $ Process.proc h $ left ++ [src]
        return $ case ecode of
            ExitSuccess -> Right (out, err)
            ExitFailure i -> Left $ RunHaskellFailure i err


resolveInterpreter :: IO [String]
resolveInterpreter = do
  stack <- Dir.findExecutable "stack"
  case stack of
      Just p -> return [p, runHaskell]
      _ -> maybeToList <$> Dir.findExecutable runHaskell


runHaskell :: String
runHaskell = "runhaskell"