# gen.awk — seeded random journals for the T4 grader's property checks and perf case.
#
#   awk -f gen.awk -v seed=N -v ntx=N [-v target=POSTINGS] [-v mutate=1]
#       [-v truth=FILE] [-v meta=FILE] < /dev/null > journal
#
# Every journal is valid (check prints OK) unless mutate=1, which adds one unit to one
# explicit amount of one transaction without an elided posting, making exactly that
# transaction UNBALANCED; meta then holds mutated_line=<its header line>.
# meta also holds net_<COMMODITY>=<units at the commodity's scale> for what cost postings
# converted (AAPL bought against USD): the per-commodity sum of the top-level balances.
# truth gets the generator's own balance report, one "ACCOUNT AMOUNT COMMODITY" line per
# account (ancestors included) and non-zero commodity, unsorted: the grader compares it
# with the solution's `balance` after sorting both. With target set, transactions are
# added until the journal has at least that many postings (ntx is then ignored).
# The random source is a Park-Miller LCG, exact in awk's doubles, so every awk gives the
# same journal for the same seed. Dates stay within 2024 and days 01-28.

function rnd(n) { st = (st * 16807) % 2147483647; return st % n }
function fmt(v, s,   neg, ip, fp, r) {
  neg = v < 0; if (neg) v = -v
  if (s == 0) return (neg ? "-" : "") v
  ip = int(v / 100); fp = v % 100
  r = ip "." (fp < 10 ? "0" : "") fp
  return (neg ? "-" : "") r
}
function date(day,   m, d) { m = int((day - 1) / 28) + 1; d = (day - 1) % 28 + 1
  return sprintf("2024-%02d-%02d", m, d) }
function amount(c) { return (rnd(2) ? 1 : -1) * (1 + rnd(c == "JPY" ? 50000 : 99999)) }
function post(k, a, c, v, el, txt) {
  np[k]++; PA[k, np[k]] = a; PC[k, np[k]] = c; PV[k, np[k]] = v; PE[k, np[k]] = el
  PT[k, np[k]] = txt; npost++
}
function addday(a, c, day, v) { DT[a, c, day] += v }
function add_truth(a, c, v,   n, i, parts, name) {
  n = split(ACC[a], parts, ":"); name = ""
  for (i = 1; i <= n; i++) { name = name (i > 1 ? ":" : "") parts[i]; TRUTH[name, c] += v; TNAME[name] = 1 }
}

BEGIN {
  st = seed % 2147483646 + 1
  NA = split("Assets:Bank:Checking Assets:Bank:Savings Assets:Cash Assets:Broker Assets-Old " \
             "Liabilities:Card Expenses Expenses:Food Expenses:Food:Groceries Expenses:Food:Dining " \
             "Expenses:Rent Expenses:Travel:Air:Intl Income:Salary Income:Interest Equity:Opening", ACC, " ")
  split("EUR USD JPY", COM, " ")
  SCALE["EUR"] = 2; SCALE["USD"] = 2; SCALE["JPY"] = 0; SCALE["AAPL"] = 0
  BROKER = 4; CHECKING = 1
  limit = target > 0 ? 1e9 : ntx
  for (k = 1; k <= limit && !(target > 0 && npost >= target); k++) {
    D[k] = 1 + rnd(336); np[k] = 0; EL[k] = 0
    r = rnd(100)
    if (r < 70) {                         # one commodity, 2-4 postings
      c = COM[1 + rnd(3)]; n = 2 + rnd(3); sum = 0
      for (j = 1; j < n; j++) { a = 1 + rnd(NA); v = amount(c); sum += v
        post(k, a, c, v, 0, ACC[a] "  " fmt(v, SCALE[c]) " " c) }
      a = 1 + rnd(NA)
      if (rnd(2)) { EL[k] = 1; post(k, a, c, -sum, 1, ACC[a]) }
      else post(k, a, c, -sum, 0, ACC[a] "  " fmt(-sum, SCALE[c]) " " c)
    } else if (r < 85) {                  # two commodities
      c1 = COM[1 + rnd(3)]; c2 = COM[1 + rnd(3)]; if (c2 == c1) c2 = (c1 == "EUR" ? "USD" : "EUR")
      a = 1 + rnd(NA); v1 = amount(c1); post(k, a, c1, v1, 0, ACC[a] "  " fmt(v1, SCALE[c1]) " " c1)
      a = 1 + rnd(NA); v2 = amount(c2); post(k, a, c2, v2, 0, ACC[a] "  " fmt(v2, SCALE[c2]) " " c2)
      a = 1 + rnd(NA)
      if (rnd(2)) { EL[k] = 1; post(k, a, c1, -v1, 1, ACC[a]); EXTRA[k] = c2; EXTRAV[k] = -v2 }
      else { post(k, a, c1, -v1, 0, ACC[a] "  " fmt(-v1, SCALE[c1]) " " c1)
             b = 1 + rnd(NA); post(k, b, c2, -v2, 0, ACC[b] "  " fmt(-v2, SCALE[c2]) " " c2) }
    } else {                              # a cost posting
      q = 1 + rnd(20); p = 10000 + rnd(20000)
      post(k, BROKER, "AAPL", q, 0, ACC[BROKER] "  " q " AAPL @ " fmt(p, 2) " USD")
      COST[k] = 1; NET["AAPL"] += q; NET["USD"] -= q * p
      if (rnd(2)) { EL[k] = 1; post(k, CHECKING, "USD", -q * p, 1, ACC[CHECKING]) }
      else post(k, CHECKING, "USD", -q * p, 0, ACC[CHECKING] "  " fmt(-q * p, 2) " USD")
    }
    for (j = 1; j <= np[k]; j++) {
      if (PV[k, j] != 0) { addday(PA[k, j], PC[k, j], D[k], PV[k, j]); add_truth(PA[k, j], PC[k, j], PV[k, j]) }
    }
    if (k in EXTRA && EXTRAV[k] != 0) {   # the elided posting's second amount
      a = PA[k, np[k]]; addday(a, EXTRA[k], D[k], EXTRAV[k]); add_truth(a, EXTRA[k], EXTRAV[k])
    }
    if (rnd(10) == 0) ASSERT[k] = 1       # on the first posting
  }
  NT = k - 1
  # The mutated transaction: the first one at or after a random start with no elided posting.
  MUT = 0
  if (mutate) for (i = 0; i < NT && !MUT; i++) { k = 1 + (rnd(NT) + i) % NT; if (!EL[k] && !COST[k]) MUT = k }

  line = 0
  for (a = 1; a <= NA; a++) if (a % 4 != 0) { print "2020-01-01 open " ACC[a]; line++ }
  print "2025-06-30 close Liabilities:Card"; line++
  for (m = 1; m <= 12; m++) {
    print "P " date((m - 1) * 28 + 1) " USD 0.9" rnd(10) " EUR"
    print "P " date((m - 1) * 28 + 1 + rnd(28)) " JPY 0.01 EUR"
    print "P " date((m - 1) * 28 + 1 + rnd(28)) " AAPL " (100 + rnd(100)) "." (10 + rnd(90)) " EUR"
    print "P " date((m - 1) * 28 + 1) " AAPL " (100 + rnd(100)) "." (10 + rnd(90)) " USD"
    line += 4
  }
  print ""; line++
  for (k = 1; k <= NT; k++) {
    print date(D[k]) " " (rnd(2) ? "*" : "!") " txn " k; line++
    if (k == MUT) mutated_line = line
    for (j = 1; j <= np[k]; j++) {
      txt = PT[k, j]
      if (k == MUT && j == 1) { c = PC[k, 1]; txt = ACC[PA[k, 1]] "  " fmt(PV[k, 1] + 1, SCALE[c]) " " c }
      if (j == 1 && (k in ASSERT)) {
        sum = 0; a = PA[k, 1]; c = PC[k, 1]
        for (d = 1; d <= D[k]; d++) if ((a, c, d) in DT) sum += DT[a, c, d]
        txt = txt " = " fmt(sum, SCALE[c]) " " c
      }
      print "    " txt; line++
    }
    if (rnd(8) == 0) { print "; a comment between transactions"; line++ }
  }
  for (a = 1; a <= NA; a++) if (a % 4 == 0) { print "2020-01-01 open " ACC[a]; line++ }

  if (truth != "") {
    printf "" > truth
    for (key in TRUTH) {
      split(key, kp, SUBSEP)
      if (TRUTH[key] != 0) print kp[1] " " fmt(TRUTH[key], SCALE[kp[2]]) " " kp[2] > truth
    }
    close(truth)
  }
  if (meta != "") {
    print "mutated_line=" mutated_line > meta
    print "postings=" npost > meta
    print "reg=" ACC[1 + rnd(NA)] > meta
    split(ACC[1 + rnd(NA)], top, ":")
    print "regtop=" top[1] > meta
    print "end=" date(1 + rnd(336)) > meta
    # What cost postings converted: top-level balances sum to this, not to zero.
    for (c in NET) print "net_" c "=" NET[c] > meta
    close(meta)
  }
}
