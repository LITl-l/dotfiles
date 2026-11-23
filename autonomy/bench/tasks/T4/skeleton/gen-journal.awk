# gen-journal.awk — the large journal that the Performance requirement in SPEC.md is
# measured on.
#
#   awk -f gen-journal.awk -v postings=500000 > big.journal
#
# It prints a valid journal (check prints OK) with at least that many postings: open and
# close directives, monthly prices, one- and two-commodity transactions, elided postings,
# cost postings and balance assertions. The same arguments always give the same journal,
# with any awk. seed=N picks another journal of the same shape.

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
function post(k, a, c, v, txt) {
  np[k]++; PA[k, np[k]] = a; PC[k, np[k]] = c; PV[k, np[k]] = v; PT[k, np[k]] = txt; npost++
}

BEGIN {
  if (postings == "") postings = 500000
  if (seed == "") seed = 424242
  st = seed % 2147483646 + 1
  NA = split("Assets:Bank:Checking Assets:Bank:Savings Assets:Cash Assets:Broker Assets-Old " \
             "Liabilities:Card Expenses Expenses:Food Expenses:Food:Groceries Expenses:Food:Dining " \
             "Expenses:Rent Expenses:Travel:Air:Intl Income:Salary Income:Interest Equity:Opening", ACC, " ")
  split("EUR USD JPY", COM, " ")
  SCALE["EUR"] = 2; SCALE["USD"] = 2; SCALE["JPY"] = 0; SCALE["AAPL"] = 0
  BROKER = 4; CHECKING = 1
  for (k = 1; npost < postings; k++) {
    D[k] = 1 + rnd(336); np[k] = 0
    r = rnd(100)
    if (r < 70) {                         # one commodity, 2-4 postings
      c = COM[1 + rnd(3)]; n = 2 + rnd(3); sum = 0
      for (j = 1; j < n; j++) { a = 1 + rnd(NA); v = amount(c); sum += v
        post(k, a, c, v, ACC[a] "  " fmt(v, SCALE[c]) " " c) }
      a = 1 + rnd(NA)
      if (rnd(2)) post(k, a, c, -sum, ACC[a])
      else post(k, a, c, -sum, ACC[a] "  " fmt(-sum, SCALE[c]) " " c)
    } else if (r < 85) {                  # two commodities
      c1 = COM[1 + rnd(3)]; c2 = COM[1 + rnd(3)]; if (c2 == c1) c2 = (c1 == "EUR" ? "USD" : "EUR")
      a = 1 + rnd(NA); v1 = amount(c1); post(k, a, c1, v1, ACC[a] "  " fmt(v1, SCALE[c1]) " " c1)
      a = 1 + rnd(NA); v2 = amount(c2); post(k, a, c2, v2, ACC[a] "  " fmt(v2, SCALE[c2]) " " c2)
      a = 1 + rnd(NA)
      if (rnd(2)) { post(k, a, c1, -v1, ACC[a]); EXTRA[k] = c2; EXTRAV[k] = -v2 }
      else { post(k, a, c1, -v1, ACC[a] "  " fmt(-v1, SCALE[c1]) " " c1)
             b = 1 + rnd(NA); post(k, b, c2, -v2, ACC[b] "  " fmt(-v2, SCALE[c2]) " " c2) }
    } else {                              # a cost posting
      q = 1 + rnd(20); p = 10000 + rnd(20000)
      post(k, BROKER, "AAPL", q, ACC[BROKER] "  " q " AAPL @ " fmt(p, 2) " USD")
      if (rnd(2)) post(k, CHECKING, "USD", -q * p, ACC[CHECKING])
      else post(k, CHECKING, "USD", -q * p, ACC[CHECKING] "  " fmt(-q * p, 2) " USD")
    }
    # Day totals per account and commodity, for the assertions below.
    for (j = 1; j <= np[k]; j++) if (PV[k, j] != 0) DT[PA[k, j], PC[k, j], D[k]] += PV[k, j]
    if (k in EXTRA && EXTRAV[k] != 0) DT[PA[k, np[k]], EXTRA[k], D[k]] += EXTRAV[k]
    if (rnd(10) == 0) ASSERT[k] = 1       # on the first posting
  }
  NT = k - 1

  for (a = 1; a <= NA; a++) if (a % 4 != 0) print "2020-01-01 open " ACC[a]
  print "2025-06-30 close Liabilities:Card"
  for (m = 1; m <= 12; m++) {
    print "P " date((m - 1) * 28 + 1) " USD 0.9" rnd(10) " EUR"
    print "P " date((m - 1) * 28 + 1 + rnd(28)) " JPY 0.01 EUR"
    print "P " date((m - 1) * 28 + 1 + rnd(28)) " AAPL " (100 + rnd(100)) "." (10 + rnd(90)) " EUR"
    print "P " date((m - 1) * 28 + 1) " AAPL " (100 + rnd(100)) "." (10 + rnd(90)) " USD"
  }
  print ""
  for (k = 1; k <= NT; k++) {
    print date(D[k]) " " (rnd(2) ? "*" : "!") " txn " k
    for (j = 1; j <= np[k]; j++) {
      txt = PT[k, j]
      if (j == 1 && (k in ASSERT)) {
        sum = 0; a = PA[k, 1]; c = PC[k, 1]
        for (d = 1; d <= D[k]; d++) if ((a, c, d) in DT) sum += DT[a, c, d]
        txt = txt " = " fmt(sum, SCALE[c]) " " c
      }
      print "    " txt
    }
    if (rnd(8) == 0) print "; a comment between transactions"
  }
  for (a = 1; a <= NA; a++) if (a % 4 == 0) print "2020-01-01 open " ACC[a]
}
