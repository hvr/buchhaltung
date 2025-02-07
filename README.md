# Buchhaltung  [![Build Status](https://travis-ci.org/johannesgerer/buchhaltung.svg?branch=master)](https://travis-ci.org/johannesgerer/buchhaltung) [![Hackage](https://img.shields.io/hackage/v/buchhaltung.svg)](https://hackage.haskell.org/package/buchhaltung)

> What advantages does he derive from the system of book-keeping by double entry! It is among the finest inventions of the human mind; every prudent master of a house should introduce it into his economy.
> -- Johann Wolfgang von Goethe

*Buchhaltung* (['bu&#720;&chi;ˌhaltʊŋ], German *book keeping*), written in Haskell, helps you keep track of your finances on the commandline with minimal effort. It provides tools that help you in creating a complete ledger of all your bank and savings accounts', credit cards', and other transactions, in a text-based ledger format, that is readable by the [ledger CLI tool](http://www.ledger-cli.org/) and its many [derivatives](http://plaintextaccounting.org/).

* Fetch your bank transaction directly via FinTS/HBCI/OFXDirectConnect
* Import transactions from PayPal (can be customized to other formats)
* Semi-automatically match transactions to accounts using Bayesian classification
* Semi-automatic transaction entry with meaningful suggestions in keyboard-based speed mode
 * It is couples/room-mates aware: Create several transaction simultaniuously (see [Multi-user add](#multi-user-add))

## Status & aim

I am actively and successfully using this software since 2010 and my ledger now contains more than 12,000 transactions accurately and continuously tracking the finances of my spouse and me including four checking and two savings accounts, one credit card, two paypal accounts, two cash wallets in EUR, bitcoin trading (both physical and on exchanges) and other currencies like USD, GPB used on trips.

The software is in alpha phase and I am looking for early adopters and their use cases. The aim of this stage is to agree about the functionality and customizability and produce a first shipable version, that can be used without tinkering with the source.

Right now, I am using it on Linux but it should also run wherever GHC runs.

# Installation

## Prerequisites

* [Haskell Stack](https://haskell-lang.org/get-started), more specifically the [Glasgow Haskell Compiler](https://www.haskell.org/) and [Stack](https://docs.haskellstack.org/en/stable/README/)

  Required to **compile** the software.
  
* [AqBanking Command Line Tool](http://www2.aquamaniac.de/sites/aqbanking/index.php) (optional)

  This is required for **direct retrieval of bank transactions** via FinTS/HBCI/EBICS (Germany) or OFXDirectConnect (USA, Canada, UK). Packages available e.g. on Ubuntu (aqbanking-tools) and ArchLinux (aqbanking). (AqBanking is also the used by [GnuCash](http://wiki.gnucash.org/wiki/AqBanking) for this purpose.)

* [dbacl](http://dbacl.sourceforge.net/) (optional, needed to run [`match`](#match-accounts))

  Bayesian classifier used to **match transaction to accounts**. Packages available e.g. on Ubuntu and ArchLinux ([AUR](https://aur.archlinux.org/packages/dbacl/)).

* [ledger CLI tool](http://www.ledger-cli.org/) or a compatible [derivative](http://plaintextaccounting.org/) (optional)

  ... to **query the ledger, create balance and report statements**, [web interface](http://hledger.org/hledger-web.html), etc.

## Download, compile & install

```shell
# download
git clone https://github.com/johannesgerer/buchhaltung.git
cd buchhaltung


# compile and install (usually in ~/.local/bin)
stack install

```

## Configure

1. Create a folder that will hold all your config and possibly ledger files:
    
    ```shell
    mkdir ~/.buchhaltung
    cp /path/to/buchhaltung/config.yml ~/.buchhaltung/config.yml
    ```
    
    If you want a folder under a different location, either create a symlink or set the `BUCHHALTUNG` environment variable to that location.

2. Edit the `config.yml`.

3. Make sure the configured ledger files exist.

# Getting help

* The `config.yml` file provides excessive comments.
* This readme documents most functionality.
* Every command and subcommand shows a help message when invoked with `-h`.
* Read the haddock documentation and source code on [Hackage](https://hackage.haskell.org/package/hashtables).
* Open an issue.
* Write an email.

# Usage

## First usage / clean

To initialize AqBanking after you edited the config file, you need to run:

```shell
buchhaltung setup
```

To clean everythink aqbanking related remove the configured `aqBanking.configDir`  and rerun the `setup` command.

### Manual AqBanking setup

Currently only the `PinTan` method is supportend (pull requests welcome). For other methods or if the AqBanking setup fails due to other reasons, you can configure AqBanking manually into the configured `aqBanking.configDir` (see for help [here](https://www.aquamaniac.de/sites/download/download.php?package=09&release=09&file=01&dummy=aqbanking4-handbook-20091231.pdf) or [here](https://wiki.gnucash.org/wiki/AqBanking), usually via `aqhbci-tool4 -C <aqBanking.configDir>`).

## Importing transactions

There various ways (including from PayPal CSV files) to import transactions into your configured `ledgers.imported` file. They are presented in the folling, but consult

```shell
buchhaltung import -h
```

and the `-h` calls to its subcommands to see the currently available functionality.

The accounts of the imported transactions will be taken from the configured `bankAccounts` and the offsetting balaence will be posted to an account named `TODO`, and will be replaced by [`match`](#match-accounts).

The original source information will be included in the second posting's comment and used for learning the account mappings and to find and handle duplicates.

### AqBanking

```shell
buchhaltung update
```

This command fetches and imports all available transactions from all configured AqBanking connections.


### Resolve duplicates

Banks often minimally change the way they report transactions which leads to unwanted duplicates.

When importing, *Buchhaltung* will identify duplicates based on `([(Commodity,Quantity)], AccountName, Day)` and interactively resolve them by showing the user what fields have changed. If there are several candidates, it sorts the candidates according to similarity using `levenshteinDistance` from [edit-distance](https://hackage.haskell.org/package/edit-distance-0.2.1.3). (See [`Buchhaltung.Uniques.addNew`](https://github.com/johannesgerer/buchhaltung/blob/master/src/Buchhaltung/Uniques.hs#L27))

## Match accounts

```shell
buchhaltung match
```

This command asks the user for the offsetting accounts of imported transactions, or more specifically, transaction whose second posting's account begins with `TODO`. 

Have a look at the example output [here](match.md).

The significantly speed up this process, it learns the account mapping from existing transactions in the configured `ledgers.imported` file using the original source of the imported tansaction.  

See [this](#input-and-tab-completion) information about the account input field.


### Best practices
 
The Bayesian classifier can only work if similar transactions are always matched with the same account.

Consider frequent credit card payments to Starbucks:

* Match them with `Expenses:Food:Starbucks` if you know that these should always be booked to that account.

* Match them with `Accounts receivable:Starbucks` and [manually enter](#enter-transactions) your paper receipts if 

    * you want to make sure they charge you the correct amounts.
    
    * you sometimes order for friends and get reimbursed later.
    
    * ...

## Enter transactions

```shell
buchhaltung add
```

This command opens a transaction editor. [Here](add.md) is an example of the output of this command.

The amount of manual typing is kept to a minimum by two clever suggestion mechanisms and TAB completion.

### Input and TAB completion

All input fields save their history in the current directory. It can be browsed using up and down arrow keys.

The account input fields support TAB completion. To make this even more useful, the account hierarchy is read in reverse order. For example `Expenses:Food` has to be entered as `Food:Expenses`.

### Suggested transactions

After the amount is entered, the user can select a transaction whose title, date, amount and second posting's account will used to prefill an offsetting transaction. Suggestions will consist of all transactions

* whose second posting has not been cleared (i.e. marked with an asterisk in front of the account name, and
* whose first posting's amount has the absolute value as the entered amount
* whose first posting's account is contained in the configured `bankAccounts` and does not match any of regexes in `ignoredAccountsOnAdd`.

### Suggested accounts

Once the first posting's account has been entered, the editor suggests accounts for the second posting based on the frequecy of the resulting transaction's accounts in the configured `ledgers.addedByThisUser` file.

### Assertions \& assignments

Amounts can be entered with [assertions](http://hledger.org/manual.html#balance-assertions) or can be [assigned](http://hledger.org/manual.html#balance-assignments). 

### Default currency

In order to be able to enter naked amounts and have the currency added automatically, add a [default currency](http://hledger.org/manual.html#default-commodity) to the configured `addedByThisUser` ledger file. Example:

```
D 1,000.000 EUR
```


### Multi-user add

```shell
buchhaltung add -w alice
```

If there is more than one user configured — possibly each with their own ledger, they can be included/activated via the commandline argument `-w`. This enables you to enter a transaction where postings belong to different users. When done, a transaction for each user will be generated containing their respective postings and a balancing posting to an account prefixed with the configured `accountPrefixOthers`.

Example taken from the [output](add_multi_user.md) of the above command:

```shell
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

2016/12/19 Dinner

        Account          |  Amount  | Assertion
-------------------------+----------+-----------+----------
0,jo    Wallet:Assets    | $ -100.0 |           |
1,jo    Food:Expenses    | $ 50     |           |
2,alice Food:Expenses    | $ 50     |           |
-------------------------+----------+-----------+----------
Open Balance             | 0        |
```

generates the following transactions

```shell
#######  jo:  Balanced Transaction   #######

2016/12/19 Dinner    ; Entered on "2016-12-19T19:01:00Z" by 'buchhaltung' user jo
    Wallet:Assets                             $ -100.0
    Food:Expenses                                 $ 50
    Accounts receivable:Friends:alice:jo          $ 50



#######  alice:  Balanced Transaction   #######

2016/12/19 Dinner    ; Entered on "2016-12-19T19:01:00Z" by 'buchhaltung' user jo
    Accounts receivable:Friends:jo:jo         $ -50
    Food:Expenses                              $ 50
```

## Getting results

### Get current AqBanking account balances

```shell
buchhaltung lb
```

### Call `ledger` or `hledger`

```shell
buchhaltung ledger

buchhaltung hledger
```

This calls the respective program with the `LEDGER` environment variable set to the configured `mainLedger` or `mainHledger`.

### Commit the changes

```shell
buchhaltung commit -a -m'checking account ok'
```

this commits all changes to the git repository that contains the `mainLedger` file. The commit message will also contain the output of `buchhaltung lb` and `buchhaltung ledger balance --end tomorrow`.
