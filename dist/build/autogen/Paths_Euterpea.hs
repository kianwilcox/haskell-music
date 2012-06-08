module Paths_Euterpea (
    version,
    getBinDir, getLibDir, getDataDir, getLibexecDir,
    getDataFileName
  ) where

import Data.Version (Version(..))
import System.Environment (getEnv)

version :: Version
version = Version {versionBranch = [1,0,0], versionTags = []}

bindir, libdir, datadir, libexecdir :: FilePath

bindir     = "/Users/kianwilcox/Library/Haskell/ghc-7.0.3/lib/Euterpea-1.0.0/bin"
libdir     = "/Users/kianwilcox/Library/Haskell/ghc-7.0.3/lib/Euterpea-1.0.0/lib"
datadir    = "/Users/kianwilcox/Library/Haskell/ghc-7.0.3/lib/Euterpea-1.0.0/share"
libexecdir = "/Users/kianwilcox/Library/Haskell/ghc-7.0.3/lib/Euterpea-1.0.0/libexec"

getBinDir, getLibDir, getDataDir, getLibexecDir :: IO FilePath
getBinDir = catch (getEnv "Euterpea_bindir") (\_ -> return bindir)
getLibDir = catch (getEnv "Euterpea_libdir") (\_ -> return libdir)
getDataDir = catch (getEnv "Euterpea_datadir") (\_ -> return datadir)
getLibexecDir = catch (getEnv "Euterpea_libexecdir") (\_ -> return libexecdir)

getDataFileName :: FilePath -> IO FilePath
getDataFileName name = do
  dir <- getDataDir
  return (dir ++ "/" ++ name)
