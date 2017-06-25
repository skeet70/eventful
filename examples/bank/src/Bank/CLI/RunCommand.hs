module Bank.CLI.RunCommand
  ( runCLICommand
  ) where

import Control.Monad (void)
import Database.Persist.Sqlite

import Eventful

import Bank.Models
import Bank.CLI.Options
import Bank.CLI.Store
import Bank.ReadModels.CustomerAccounts

runCLICommand :: ConnectionPool -> CLICommand -> IO ()
runCLICommand pool (CreateCustomerCLI createCommand) = do
  uuid <- uuidNextRandom
  putStr "Attempting to create customer with UUID: "
  print uuid
  let command = CreateCustomerCommand createCommand
  void $ runDB pool $ commandStoredAggregate cliEventStore customerBankAggregate uuid command
runCLICommand pool (ViewAccountCLI uuid) = do
  latestStreamProjection <- runDB pool $
    getLatestVersionedProjection cliEventStore (versionedStreamProjection uuid accountBankProjection)
  printJSONPretty (streamProjectionState latestStreamProjection)
runCLICommand pool (ViewCustomerAccountsCLI name) = do
  events <- runDB pool $ getGlobalEvents cliGlobalStreamEventStore (allEvents ())
  let
    allCustomerAccounts = latestProjection customerAccountsProjection (streamEventEvent <$> events)
    thisCustomerAccounts = getCustomerAccountsFromName allCustomerAccounts name
  case thisCustomerAccounts of
    [] -> putStrLn "No accounts found"
    accounts -> mapM_ printJSONPretty accounts
runCLICommand pool (OpenAccountCLI openCommand) = do
  uuid <- uuidNextRandom
  putStr "Attempting to open account with UUID: "
  print uuid
  let command = OpenAccountCommand openCommand
  void $ runDB pool $ commandStoredAggregate cliEventStore accountBankAggregate uuid command
runCLICommand pool (TransferToAccountCLI sourceId amount targetId) = do
  putStrLn $ "Starting transfer from acccount " ++ show sourceId ++ " to " ++ show targetId

  transferId <- uuidNextRandom
  let startCommand = TransferToAccountCommand $ TransferToAccount transferId amount targetId
  void $ runDB pool $ commandStoredAggregate cliEventStore accountBankAggregate sourceId startCommand
  runCLICommand pool (ViewAccountCLI sourceId)
  runCLICommand pool (ViewAccountCLI targetId)
