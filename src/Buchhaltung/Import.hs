{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE OverloadedStrings #-}

module Buchhaltung.Import
where

import           Buchhaltung.Common
import           Buchhaltung.Uniques
import           Control.Applicative
import           Control.Arrow hiding (loop)
import           Control.Monad
import           Control.Monad.IO.Class
import           Control.Monad.RWS.Strict
import           Control.Monad.Reader.Class
import           Data.Default
import           Data.Either
import           Data.Function
import qualified Data.HashMap.Strict as M
import           Data.List
import           Data.Maybe
import           Data.Monoid
import           Data.Ord
import           Data.Ratio
import qualified Data.Text as T
import qualified Data.Text.IO as T
import qualified Data.Text.Lazy as TL
import           Data.Time.LocalTime
import           Hledger.Data
import           Hledger.Read
import           Safe
import           System.IO
import qualified System.IO.Strict as S
import           Text.ParserCombinators.Parsec
import           Text.Printf
import           Text.Regex
import           Text.Regex.TDFA

assertParseEqual' ::  (Either ParseError a) -> String
assertParseEqual' = const "a"

-- | convert a batch of importedEntries to Ledger Transactions 
fillTxn
  :: (MonadError Msg m, MonadReader (Options User Config env) m) =>
     T.Text -- ^ current time string
     -> ImportedEntry -> m FilledEntry
fillTxn datetime e@(ImportedEntry t (accId, am) source) = do
  tag <- askTag
  todo <- readConfig cTodoAccount
  acc <- lookupErrM "Account not configured" M.lookup accId
    =<< askAccountMap
  let tx = injectSource tag source $ 
           t{tcomment = "generated by 'buchhaltung' "
                        <> datetime <> com (tcomment t)
            ,tpostings =
             [ nullposting{paccount= acc
                           ,pamount = mamountp' $ T.unpack am }
             , nullposting{paccount= todo <> ":" <> acc
                          ,pamount = missingmixedamt }
             -- leaves amount missing. (alternative: use
             -- balanceTransaction Nothing)
             ]}
  return $ e{ieT = tx, iePostings=()}
  where
    com "" = ""
    com b = " (" <> b <> ")"


-- | read entries from handle linewise, process and add to ledger
importCat ::
     Maybe FilePath
  -- ^ File to check for already processed transactions
     -> (T.Text -> CommonM env [ImportedEntry])
     -> T.Text
     -> CommonM env Journal
importCat journalPath conv text  = do
  oldJ <- liftIO $ maybe (return mempty)
    (fmap (either error id) . readJournalFile Nothing Nothing False)
    journalPath
  datetime <- liftIO $ fshow <$> getZonedTime
  let lookupAcc name = fromMaybe
  entries <- mapM (fillTxn datetime) =<< conv text 
  newTxns <- addNew entries oldJ
  liftIO $ hPutStrLn stderr $ printf "found %d new of %d total transactions"
    (length newTxns - length (jtxns oldJ)) $ length entries
  comp <- dateAmountSource <$> askTag
  return oldJ{jtxns = sortBy comp $ ieT <$> newTxns}

dateAmountSource
  :: ImportTag -> Transaction -> Transaction -> Ordering
dateAmountSource tag a b =
  comparing tdate a b 
  <> comparing (pamount . head . tpostings) a b
  <> comparing (fmap wSource . extractSource tag) a b

importWrite
  :: (T.Text -> CommonM env [ImportedEntry])
  -> T.Text
  -> CommonM env ()
importWrite conv text =do
  journalPath <- absolute =<< readLedger imported
  liftIO . writeJournal journalPath
    =<< importCat (Just journalPath) conv text

importHandleWrite
  :: Importer env -> FullOptions env -> Handle -> ErrorT IO ()
importHandleWrite (Importer chH conv) options handle = do
  text <- liftIO $ do
    maybe (return ()) ($ handle) chH
    liftIO (T.hGetContents handle)
  void $ runRWST (importWrite conv text) options ()
  
importReadWrite
  :: Importer env -> FullOptions env -> FilePath -> ErrorT IO ()
importReadWrite imp opt file =
  withFileM file ReadMode $ importHandleWrite imp opt

    
writeJournal :: FilePath -> Journal -> IO ()
writeJournal journalPath  =  writeFile journalPath . showTransactions
  

-- testCat :: Maybe FilePath -- ^ journal
--         -> FilePath -- ^ import
--         -> CustomImport
--         -> Bool -- ^ overwrite
--         -> IO Journal
-- testCat journalPath testfile ci overwrite =
--   withFile testfile ReadMode $ \h -> do
--   j <- importCat def journalPath ci h
--   when overwrite $ maybe mempty (flip writeJournal j) journalPath
--   return j

testRaw _ testfile (f,chH) =  withFile testfile ReadMode (\h ->
  maybe (return ()) ($ h) chH >> S.hGetContents h >>= return . show . f)


-- main = readFile "/tmp/a" >>=
--        addNew "VISA" [] "/home/data/finanzen/jo/bankimport.dat" . lines

