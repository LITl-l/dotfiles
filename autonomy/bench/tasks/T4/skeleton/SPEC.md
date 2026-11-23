# ledger — a plain-text double-entry journal checker and reporter

`./run` reads a journal on standard input and writes one report to standard output:

    ./run check                                       < journal
    ./run balance [--depth N] [--end DATE] [--value CUR] < journal
    ./run register PREFIX                             < journal

Everything `./run` prints, including every error, goes to **standard output**. `./run`
exits 0 whenever it printed its output, errors included.

The features come in five milestones, M1 to M5. Each builds on the ones before it.
`examples/M<k>/` holds worked cases for milestone k: `<name>.in` is the journal,
`<name>.args` the arguments (one per line), `<name>.out` the exact expected output.

---

## M1 — Parsing and `check`

### Lines

The journal is a sequence of lines separated by `\n`. A final line without `\n` counts.
`\r` gets no special treatment. Lines are numbered from 1. On every line, the first `;`
and everything after it is a comment and is removed first; trailing spaces and tabs are
then removed. What is left decides the kind of line:

| Left after removing the comment | Kind |
|---|---|
| nothing | blank line |
| starts with a space or a tab | posting line |
| starts with a digit | transaction header, or a dated directive |
| starts with `P` followed by a space or a tab | price directive (M5) |
| anything else | `PARSE` error |

Tokens are separated by one or more spaces or tabs.

### Dates

A date is written `YYYY-MM-DD`: exactly four digits, `-`, two digits, `-`, two digits.
A token of that shape that is not a real date of the Gregorian calendar (year 0000,
month 00 or above 12, day 00 or past the end of the month, 29 February in a year that is
not a leap year) is a `BAD_DATE` error. Where a date is expected, a token of any other
shape is a `PARSE` error.

A line that breaks the grammar is a `PARSE` error even if it also holds a bad date. A
line that fits the grammar but holds a date that does not exist is a `BAD_DATE` error.

### Transactions

A transaction is a header line followed by its posting lines. It ends at the first line
that is not a posting line; a blank line ends it too.

    2024-03-01 * Grocery store
        Expenses:Food        12.50 EUR
        Assets:Cash

**Header**: a date, then optionally a flag token `*` or `!`, then optionally a payee (the
rest of the line, free text). No report uses the payee. A line that starts with a digit
always opens a transaction, even when it is in error, unless it is a dated directive: its
second token is exactly `open` or `close`.

**Dated directive**: exactly three tokens, a date, `open` or `close`, and an account:

    2024-01-01 open Assets:Cash
    2024-12-31 close Assets:Cash

Any other form is a `PARSE` error. What they mean is M2.

**Posting line**: an account, then optionally an amount, then optionally a cost (M5),
then optionally an assertion (M5):

    ACCOUNT [AMOUNT COMMODITY [@ AMOUNT COMMODITY]] [= AMOUNT COMMODITY]

- **Account**: one or more segments joined by `:`. A segment is one or more characters
  from `A-Z a-z 0-9 - _`. Example: `Assets:Bank-1:Checking`.
- **Amount**: an optional `-`, 1 to 10 digits, then optionally `.` and 1 to 6 digits. No
  `+`, no thousands separators, no leading `.`. `-0` and `0.00` are zero.
- **Commodity**: 1 to 10 letters `A-Z`.

A posting without an amount is **elided** (M2). These are `PARSE` errors at their line:
a posting line that does not fit this grammar; an **orphan** posting line, one where the
nearest line above it that is not a posting line is not a transaction header (a
directive, a blank line, a `PARSE` line of another kind, or the start of the file); a
header with no posting lines. A posting line that does not fit the grammar is still a
posting line, so the posting lines after it are not orphans. A header with a `BAD_DATE`
and no posting lines is a `BAD_DATE` error, not a `PARSE` error.

### `check`

`./run check` prints `OK` when the journal has no error. Otherwise it prints one line per
error, `<line>: <CODE>`, ordered by line number. A line has at most one error.

When a header line has an error (`PARSE` or `BAD_DATE`), its posting lines are skipped:
none of them reports anything.

---

## M2 — Validation

### Exact decimals

All arithmetic is exact decimal arithmetic. Binary floating point gives wrong answers
here (0.1 + 0.2 is not 0.3 in binary floating point) and is not acceptable.

### Balancing

Each posting has a **weight**: its amount, or, with a cost (M5), its amount times the
cost. A transaction's **residual** is the sum of the weights of its postings that have an
amount, per commodity.

- No elided posting: every commodity's residual must be zero, else `UNBALANCED`.
- Exactly one elided posting: it receives the negated residual, one amount per commodity
  whose residual is not zero. If every residual is zero it receives no amount at all. The
  transaction is balanced either way.
- Two or more elided postings: `MULTI_ELIDED`.

`UNBALANCED` and `MULTI_ELIDED` are reported at the header line.

### Accounts: `open` and `close`

A dated directive (M1) with a date that does not exist is a `BAD_DATE` error at its line
and is otherwise ignored.

An account must be opened before it is posted to. `open` and `close` apply to that exact
account only, not to its parents or children. Directives take effect by their date,
wherever they are in the file.

An account has at most one `open` and at most one `close`. A second `open` (or `close`)
of the same account, counting in file order, is a `DUPLICATE` error at its line and is
otherwise ignored.

For a posting dated D to account A, the first of these that applies is reported at the
posting line:

1. A has no `open`, or its `open` is dated after D: `NOT_OPEN`. This holds even when A
   also has a `close`.
2. A has a `close` dated before D: `CLOSED`. A posting dated on the `close` date itself
   is accepted.

An elided posting is a posting to its account like any other, even if it receives no
amount.

### Error precedence within a transaction

A transaction's checks run in this order. Once a stage reports an error, the later
stages are not run for that transaction:

1. `PARSE` and `BAD_DATE` on any of its lines.
2. `MULTI_ELIDED`, then `UNBALANCED`.
3. `NOT_OPEN` and `CLOSED`, on every posting that has one.
4. `ASSERT_FAILED` (M5), on every posting that has one.

A transaction stopped in stage 1 or 2 contributes nothing to any balance. Every other
transaction contributes all its postings, including one stopped in stage 3 or 4.

---

## M3 — `balance`

    ./run balance [--depth N] [--end DATE]

If the journal has any error, `balance` prints exactly what `check` would print and
nothing else. Otherwise:

- An account's balance is the sum of the amounts posted to it and to all its
  descendants, per commodity. A parent account exists whenever one of its descendants
  does, even if nothing is posted to it directly.
- One line per account and commodity: `ACCOUNT AMOUNT COMMODITY`, single spaces.
  Commodities whose balance is zero are left out, and an account with no line left is
  left out. With nothing to print, the output is empty.
- Accounts are ordered by comparing their segments one at a time, bytewise; an account
  comes directly before its descendants. So `Assets`, `Assets:Cash`, `Assets-Old`. Lines
  of one account are ordered by commodity. Commodities are always ordered bytewise, so
  `A`, `AB`, `B`.
- `--depth N` (N ≥ 1) prints only accounts with at most N segments. Their balances still
  include every descendant.
- `--end DATE` counts only postings dated on or before DATE.

### Amount format

Every amount is printed with the **scale** of its commodity: the largest number of
decimals written in any amount of that commodity anywhere in the journal (posting
amounts, costs, assertions and prices, whatever `--end` says), and in any amount an
elided posting received, counted as the decimals needed to write it exactly. `-` for
negative values, no `+`, at least one digit before the point, no point when the scale is
0, and zero is never negative. Example: with EUR amounts `5` and `1.250` in the journal,
EUR prints as `5.000` and `1.250`.

---

## M4 — `register`

    ./run register PREFIX

If the journal has any error, `register` prints exactly what `check` would print.
Otherwise it prints every posting to an account that **matches** PREFIX: the account is
PREFIX itself, or starts with PREFIX followed by `:`. `Assets:Cash` matches `Assets`;
`Assets-Old` does not.

- Postings are ordered by date. Postings on the same date keep their order in the file.
- One line per posting and amount: `DATE ACCOUNT AMOUNT COMMODITY TOTAL COMMODITY`,
  single spaces.
- TOTAL is the running total of that commodity over the lines printed so far, this one
  included.
- An elided posting prints one line per amount it received, in commodity order, and no
  line if it received none.
- A posting with a cost prints its amount, not its weight.
- With nothing to print, the output is empty.

---

## M5 — Prices, costs, value and assertions

### Price directive

    P 2024-03-01 AAPL 182.50 USD

From that date on, one unit of the first commodity is worth the amount in the second.
Exactly five tokens: `P`, a date, a commodity, an amount, a commodity. The amount and
commodities follow the posting grammar (M1), and the two commodities must differ;
anything else is a `PARSE` error. A price with a date that does not exist is a `BAD_DATE`
error at its line and is otherwise ignored. Two prices for the same pair on the same
date: the later one in the file wins.

### Cost

    Assets:Broker   10 AAPL @ 150.25 USD

The posting's amount is 10 AAPL; its weight for balancing is 10 × 150.25 = 1502.50 USD.
A cost does not create a price.

### `balance --value CUR`

Converts each printed account's balance to CUR: every commodity other than CUR is
multiplied by its price in CUR, the product rounded to CUR's scale (half away from zero),
and added to the account's CUR amount. Each account converts its own balance, so a
parent's value can differ from the sum of its children's printed values. The account
then prints one line in CUR, or none if that is zero.

The price used is the latest `P` directive for that commodity in CUR dated on or before
the `--end` date, or of any date without `--end`. Prices are never inverted or chained.
A commodity has to be converted only where it has a non-zero balance in an account that
is printed (so after `--depth`); a commodity that sums to zero there needs no price. If a
commodity that has to be converted has no such price, the output is one line
`NO_PRICE COMMODITY` per such commodity, in commodity order, and nothing else.

### Assertions

    Assets:Cash   -20 EUR = 80 EUR

The balance of that exact account (not its descendants) in the asserted commodity must
equal the asserted amount. That balance counts every contributing posting to the account
dated on or before the posting's date, **including every posting on the same date**,
wherever it is in the file. Otherwise `ASSERT_FAILED` at the posting line.

---

## Usage errors

The arguments are checked before the journal is read. An unknown command, a missing or
extra argument, an unknown flag, a flag given twice, a flag for another command, a
`--depth` that is not a positive integer, an `--end` that is not a valid date, a
`--value` that is not a valid commodity, or a `register` PREFIX that is not a valid
account: print `USAGE` and nothing else. `register` takes no flags: its one argument is
always the PREFIX, and an account segment may start with `-`, so `register --depth` is
the register of the account `--depth` while `register --depth 1` is an extra argument.

---

## Quality

Besides behaviour, the result is graded on:

- The code is clean under the language's standard formatter and linter at their default
  settings.
- All source stays in the current directory.
- Large journals must be fast: see Performance.

---

## Performance

`./run balance --value EUR` on the journal that `awk -f gen-journal.awk -v postings=500000` prints must finish within 0.5 seconds of wall time on the grading machine.

That journal is about 20 MB: 500,000 postings in valid transactions of every kind above,
with prices, costs, elided postings and assertions. The generator `gen-journal.awk` is
in this directory, and the same arguments always print the same journal. To measure:

    awk -f gen-journal.awk -v postings=500000 > big.journal
    time ./run balance --value EUR < big.journal

The time counted is the median of three runs, each of which must also print the correct
report. A first run that compiles is not counted: `./run check` runs once before.
Performance is measured only when every other case passes.
