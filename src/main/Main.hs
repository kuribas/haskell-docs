{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE ViewPatterns #-}
-- | Main command-line interface.

module Main where

import           Haskell.Docs
import           Haskell.Docs.Ghc
import           Haskell.Docs.Types

import           Control.Exception
import           Control.Exception (IOException)
import qualified Control.Exception as E
import           GHC
import           GhcMonad
import           System.Environment
import           System.Exit
import           System.IO

-- | Main entry point.
main :: IO ()
main =
  do args <- getArgs
     app args

-- | Do the printing.
app :: [String] -> IO ()
app (extract -> (gs,ms,as)) =
  withInitializedPackages
    gs
    (catchErrors
       (case as of
          [name] ->
            searchAndPrintDoc ms
                              Nothing
                              Nothing
                              (Identifier name)
          [mname,name,pname] ->
            searchAndPrintDoc ms
                              (Just (PackageName pname))
                              (Just (makeModuleName mname))
                              (Identifier name)
          [mname,name] ->
            searchAndPrintDoc ms
                              Nothing
                              (Just (makeModuleName mname))
                              (Identifier name)
          _ -> bail "<module-name> <ident> [<package-name>] | <ident>\n\
                    \\n\
                    \Options: --g <ghc option> Specify GHC options.\n\
                    \         --sexp           Output s-expressions.\n\
                    \         --modules        Only output modules."))

-- | Extract arguments.
extract :: [String] -> ([String],Bool,[String])
extract = go ([],False,[])
  where
    go (gs,ms,as) ("-g":arg:ys)    = go (arg:gs,ms,as) ys
    go (gs,ms,as) ("--modules":ys) = go (gs,True,as) ys
    go (gs,ms,as) ("--sexp":ys)    = go (gs,ms,as) ys
    go (gs,ms,as) (y:ys)           = go (gs,ms,y:as) ys
    go (gs,ms,as) []               = (gs,ms,as)

-- | Catch errors and print 'em out.
catchErrors :: Ghc () -> Ghc ()
catchErrors m =
  gcatch (gcatch m
                 (\x ->
                    do bail (printEx x)
                       liftIO exitFailure))
         (\(e::SomeException) ->
            bail (show e))

-- | Print an error and bail out.
bail :: String -> Ghc ()
bail e =
  liftIO (hPutStrLn stderr e)

-- | Print an exception for humans.
printEx :: DocsException -> String
printEx e =
  case e of
    NoFindModule -> "Couldn't find any packages with that module."
    NoModulePackageCombo -> "Couldn't match a module with that package."
    NoInterfaceFiles -> "No interface files to search through! \
                        \Maybe you need to generate documentation for the package?"
    NoParseInterfaceFiles reasons -> "Couldn't parse interface files: " ++
                                     unlines (map printEx reasons)
    NoFindNameInExports -> "Couldn't find that name in an export list."
    NoFindNameInInterface -> "Couldn't find name in interface."
    NoReadInterfaceFile _ -> "Couldn't read the interface file."
