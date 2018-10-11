{-# OPTIONS_GHC -Wno-unused-imports #-}

module Education.MakeMistakesToLearnHaskell.Exercise
  ( Exercise(verify)
  , ExerciseId
  , Name
  , Result(..)
  , Details
  , loadHeaders
  , loadDescriptionById
  , loadExampleSolution
  , loadLastShown
  , saveLastShownId
  , unsafeGetById
  ) where


#include <imports/external.hs>

import qualified Paths_makeMistakesToLearnHaskell

import           Education.MakeMistakesToLearnHaskell.Diagnosis
import           Education.MakeMistakesToLearnHaskell.Env
import           Education.MakeMistakesToLearnHaskell.Evaluator.Regex
import qualified Education.MakeMistakesToLearnHaskell.Evaluator.RunHaskell as RunHaskell
import           Education.MakeMistakesToLearnHaskell.Evaluator.Types
import           Education.MakeMistakesToLearnHaskell.Exercise.Record
import           Education.MakeMistakesToLearnHaskell.Exercise.Types
import           Education.MakeMistakesToLearnHaskell.Error
import           Education.MakeMistakesToLearnHaskell.Text

import           Debug.NoTrace


exercises :: Vector Exercise
exercises = Vector.fromList [exercise1, exercise2, exercise3, exercise4]
  where
    exercise1 =
      Exercise "1" $ runHaskellExercise diag1 "Hello, world!\n"

    diag1 :: Diagnosis
    diag1 code msg
      | "parse error on input" `Text.isInfixOf` msg
          && "'" `Text.isInfixOf` code =
            "HINT: In Haskell, you must surround string literals with double-quote '\"'. Such as \"Hello, world\"."
      | ("parse error" `Text.isInfixOf` msg || "Parse error" `Text.isInfixOf` msg)
          && "top-level declaration expected." `Text.isInfixOf` msg =
            "HINT: This error indicates you haven't defined main function."
      | "Variable not in scope: main :: IO" `Text.isInfixOf` msg =
        "HINT: This error indicates you haven't defined main function."
      | "Variable not in scope:" `Text.isInfixOf` msg =
        "HINT: you might have misspelled 'putStrLn'."
      | otherwise = ""

    exercise2 =
      Exercise "2" $ runHaskellExercise diag2 "20.761245674740486\n"

    diag2 :: Diagnosis
    diag2 code msg
      | "parse error" `Text.isInfixOf` msg || "Parse error" `Text.isInfixOf` msg =
        if "top-level declaration expected." `Text.isInfixOf` msg
          then
            "HINT: This error indicates you haven't defined main function."
          else
            -- TODO: Use regex or ghc tokenizer
            case compare (Text.count "(" code) (Text.count ")" code) of
                GT -> "HINT: you might have forgot to write close parenthesis"
                LT -> "HINT: you might have forgot to write open parenthesis"
                EQ -> ""
      | "No instance for (Fractional (IO ()))" `Text.isInfixOf` msg || "No instance for (Num (IO ()))" `Text.isInfixOf` msg =
        "HINT: you might have forgot to write parentheses"
      | "No instance for (Show (a0 -> a0))" `Text.isInfixOf` msg =
        "HINT: you might have forgot to write some numbers between operators ('*', '/' etc.)."
      | "No instance for (Num (t0 -> a0))" `Text.isInfixOf` msg =
        "HINT: you might have forgot to write multiplication operator '*'"
      | "No instance for (Fractional (t0 -> a0))" `Text.isInfixOf` msg =
        "HINT: you might have forgot to write division operator '/'"
      | "Variable not in scope: main :: IO" `Text.isInfixOf` msg =
        "HINT: This error indicates you haven't defined main function."
      | otherwise = ""

    exercise3 =
      Exercise "3" $ runHaskellExercise diag3 $ Text.unlines
        [ "#     # ####### #       #        #####"
        , "#     # #       #       #       #     #"
        , "#     # #       #       #       #     #"
        , "####### #####   #       #       #     #"
        , "#     # #       #       #       #     #"
        , "#     # #       #       #       #     #"
        , "#     # ####### ####### #######  #####"
        ]

    diag3 :: Diagnosis
    diag3 code msg
      | code `isInconsistentlyIndentedAfter` "do" = detailsDoConsistentWidth
      | "parse error on input" `Text.isInfixOf` msg
          && "'" `Text.isInfixOf` code =
            "HINT: In Haskell, you must surround string literals with double-quote '\"'. Such as \"Hello, world\"."
      | ("parse error" `Text.isInfixOf` msg || "Parse error" `Text.isInfixOf` msg)
          && "top-level declaration expected." `Text.isInfixOf` msg =
            "HINT: This error indicates you haven't defined main function."
      | "Variable not in scope: main :: IO" `Text.isInfixOf` msg =
        "HINT: This error indicates you haven't defined main function."
      | "Variable not in scope:" `Text.isInfixOf` msg =
        "HINT: you might have misspelled 'putStrLn'."
      | "Couldn't match expected type ‘(String -> IO ())" `Text.isInfixOf` msg =
          detailsForgetToWriteDo "`putStrLn`s"
      | otherwise = ""

    exercise4 =
      Exercise "4" $ runHaskellExerciseWithStdin diag4 (Text.pack . unlines . reverse . lines . Text.unpack)

    diag4 :: Diagnosis
    diag4 code msg
      | code `isInconsistentlyIndentedAfter` "do" =
        detailsDoConsistentWidth
      | "Perhaps this statement should be within a 'do' block?" `Text.isInfixOf` msg =
        if hasNoMainFirst code then
          "HINT: Your source code dosn't have `main` function!"
          -- ^ TODO: Rewrite other no-main cases with this.
        else if code `containsSequence` ["main", "<-"] then
          "HINT: Don't use `<-` to define the `main` function. Use `=` instead."
        else
          detailsForgetToWriteDo "`putStr`s and `getContents`"
      | "Perhaps you need a 'let' in a 'do' block?" `Text.isInfixOf` msg
        && code `containsSequence` ["=", "getContents"] =
          "HINT: Don't assign the result of `getContents` with `=`. Use `<-` instead."
      | "Couldn't match type ‘IO String’ with ‘[Char]’" `Text.isInfixOf` msg
        && "In the first argument of ‘lines’" `Text.isInfixOf` msg =
          "HINT: Unfortunately, you have to assign the result of `getContents` with `<-` operator."
      | otherwise = error "TODO"

      where
        matchParentheses :: SourceCode -> Details
        matchParentheses code =
          let mToks = filter ((/= GHC.SpaceTok) . fst) . dropWhile (/= openParen) <$> GHC.tokenizeHaskell (Text.toStrict code)
          in
            case mToks of
                Just toks -> error "TODO"
                _ -> ""

        openParen :: (GHC.Token, TextS.Text)
        openParen = (GHC.SymbolTok, "(")


    detailsForgetToWriteDo :: Text -> Details
    detailsForgetToWriteDo funcNames =
      "HINT: You seem to forget to write `do`. `do` must be put before listing " <> funcNames <> "."


    detailsDoConsistentWidth :: Details
    detailsDoConsistentWidth = "HINT: instructions in a `do` must be in a consistent width."


-- TODO: Incomplete implementaion! Use regex or ghc tokenizer!
containsSequence :: SourceCode -> [Text] -> Bool
containsSequence code wds =
  Text.concat wds `isInWords` ws || (wds `List.isInfixOf` ws)
  where
    ws = Text.words code


isInconsistentlyIndentedAfter :: SourceCode -> Text -> Bool
isInconsistentlyIndentedAfter code wd =
  not
    $ allSame
    $ map (Text.length . Text.takeWhile Char.isSpace)
    $ cropAfterWord wd
    $ Text.lines code
  where
    cropAfterWord :: Text -> [SourceCode] -> [SourceCode]
    cropAfterWord w ls =
      -- Against my expectaion,
      -- 'dropWhile (isInWords w . Text.words) ls' returns ls as is.
      -- While this function should return an empty list
      -- if 'ls' doesn't contain 'w'.
      let (_nonContaining, containing) = List.break (isInWords w . Text.words) ls
      in
        if null containing
          then []
          else drop 1 containing
          -- ^ except the first line, which contains 'w'


isInWords :: Text -> [Text] -> Bool
isInWords wd = any (Text.isInfixOf wd)


allSame :: Eq a => [a] -> Bool
allSame [] = True
allSame [_] = True
allSame (x1 : x2 : xs) = x1 == x2 && allSame xs


hasNoMainFirst :: SourceCode -> Bool
hasNoMainFirst src =
  case Text.words src of
      [] -> True
      (h : _) -> not $ "main" `Text.isPrefixOf` h





-- TODO: refactor with resultForUser
runHaskellExercise :: Diagnosis -> Text -> Env -> FilePath -> IO Result
runHaskellExercise diag right e prgFile = do
  result <- runHaskell e defaultRunHaskellParameters { runHaskellParametersArgs = [prgFile] }
  case result of
      Right (outB, _errB {- TODO: print stderr -}) -> do
        let out = canonicalizeNewlines outB
            msg =
              Text.unlines
                [ Text.replicate 80 "="
                , "Your program's output: " <> Text.pack (show out) -- TODO: pretty print
                , "      Expected output: " <> Text.pack (show right)
                ]
        return $
          if out == right
            then Success $ "Nice output!\n\n" <> msg
            else Fail $ "Wrong output!\n\n" <> msg
      Left err -> do
        traceM $ "err: " ++ show err
        case err of
            RunHaskell.RunHaskellNotFound ->
              return $ Error "runhaskell command is not available.\nInstall stack or Haskell Platform."
            RunHaskell.RunHaskellFailure _ msg -> do
              logDebug e $ "RunHaskellFailure: " <> msg
              code <- Text.readFile prgFile
              return $ Fail $ appendDiagnosis diag code msg


runHaskellExerciseWithStdin :: Diagnosis -> (Text -> Text) -> Env -> FilePath -> IO Result
runHaskellExerciseWithStdin diag calcRight e prgFile = do
  resultRef <- newIORef $ error "Assertion failure: no result written after QuickCheck"
  qr <- quickCheckWithResult QuickCheck.stdArgs { QuickCheck.chatty = False } $ \ls ->
    QuickCheck.ioProperty $ do
      let input = Text.pack $ unlines ls
          params = defaultRunHaskellParameters
            { runHaskellParametersArgs = [prgFile]
            , runHaskellParametersStdin = TextEncoding.encodeUtf8 input
            }
      code <- Text.readFile prgFile
      result <- resultForUser diag code ["            For input: " <> Text.pack (show input)] calcRight input <$> runHaskell e params
      writeIORef resultRef result
      return $
        case result of
            Success _ -> True
            _other -> False
  logDebug e $ ByteString.pack $ "QuickCheck result: " ++ show qr
  readIORef resultRef


resultForUser :: Diagnosis -> Text -> [Text] -> (Text -> Text) -> Text -> Either RunHaskellError (ByteString, ByteString) -> Result
resultForUser _diag _code messageFooter calcRight input (Right (outB, _errB {- TODO: print stderr -})) =
  let out = canonicalizeNewlines outB
      right = calcRight input
      msg =
        Text.unlines $
          [ Text.replicate 80 "="
          , "Your program's output: " <> Text.pack (show out) -- TODO: pretty print
          , "      Expected output: " <> Text.pack (show right)
          ] ++ messageFooter
  in
    if right == out
      then Success $ "Nice output!\n\n" <> msg
      else Fail $ "Wrong output!\n\n" <> msg
resultForUser _diag _code _messageFooter _calcRight _minput (Left RunHaskell.RunHaskellNotFound) =
  Error "runhaskell command is not available.\nInstall stack or Haskell Platform."
resultForUser diag code _messageFooter _calcRight _minput (Left (RunHaskell.RunHaskellFailure _ msg)) =
  Fail $ appendDiagnosis diag code msg


loadHeaders :: IO [Text]
loadHeaders = mapM loadHeader $ Vector.toList exercises
  where
    loadHeader ex = extractHeader ex =<< loadDescription ex
    extractHeader ex desc =
      dieWhenNothing ("The description of exercise '" ++ exerciseName ex ++ "' is empty!")
        $ cutHash <$> headMay (Text.lines desc)
    cutHash h =
      Text.strip $ fromMaybe h $ Text.stripPrefix "# " h


loadDescription :: Exercise -> IO Text
loadDescription = loadWithExtension ".md"


loadExampleSolution :: Exercise -> IO Text
loadExampleSolution = loadWithExtension ".hs"


loadWithExtension :: String -> Exercise -> IO Text
loadWithExtension ext ex =
  Paths_makeMistakesToLearnHaskell.getDataFileName ("assets/" ++ exerciseName ex ++ ext)
    >>= Text.readFile


loadDescriptionById :: ExerciseId -> IO (Maybe Text)
loadDescriptionById n = MaybeT.runMaybeT $ do
  ex <- Error.hoistMaybe $ getById n
  liftIO $ loadDescription ex


-- Handle error internally.
-- Because lastShownId is usually saved internally.
loadLastShown :: Env -> IO Exercise
loadLastShown e =
  loadLastShownId e >>=
    dieWhenNothing "Assertion failure: Invalid lastShownId saved! " . getById


getById :: ExerciseId -> Maybe Exercise
getById n = exercises !? (n - 1)


unsafeGetById :: ExerciseId -> Exercise
unsafeGetById n = exercises ! (n - 1)
