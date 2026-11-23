/* ledger — the T4 reference: a plain-text double-entry journal checker and reporter.
 *
 * Amounts are exact: an __int128 count of 10^-12 units. Literals carry at most 6
 * decimals, so a cost weight (amount x cost) has at most 12 and is still exact.
 * The broken variants under grader/broken/ are sed edits of this file, so the lines
 * they target are spelled once.
 */
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef __int128 i128;

#define SC 12 /* internal decimals */
#define MAXTOK 10

static void die(const char *msg) {
  fprintf(stderr, "ledger: %s\n", msg);
  exit(2);
}

static void *xrealloc(void *p, size_t n) {
  p = realloc(p, n ? n : 1);
  if (!p)
    die("out of memory");
  return p;
}

#define GROW(arr, n, cap)                                                      \
  do {                                                                         \
    if ((n) >= (cap)) {                                                        \
      (cap) = (cap) ? (cap) * 2 : 64;                                          \
      (arr) = xrealloc((arr), (size_t)(cap) * sizeof *(arr));                  \
    }                                                                          \
  } while (0)

static i128 p10(int k) {
  i128 r = 1;
  while (k-- > 0)
    r *= 10;
  return r;
}

/* ------------------------------------------------------------ output buffer */

static char *ob;
static size_t on, ocap;

static void out(const char *s, size_t n) {
  if (on + n > ocap) {
    while (on + n > ocap)
      ocap = ocap ? ocap * 2 : 1 << 16;
    ob = xrealloc(ob, ocap);
  }
  memcpy(ob + on, s, n);
  on += n;
}
static void outs(const char *s) { out(s, strlen(s)); }
static void outc(char c) { out(&c, 1); }
static void flush(void) {
  if (on && fwrite(ob, 1, on, stdout) != on)
    die("write failed");
  on = 0;
}

static void out_int(i128 v) {
  char b[64];
  int n = 0;
  if (v < 0) {
    outc('-');
    v = -v;
  }
  do {
    b[n++] = (char)('0' + (int)(v % 10));
    v /= 10;
  } while (v > 0);
  while (n > 0)
    outc(b[--n]);
}

/* v is in 10^-12 units and has at most `scale` decimals. */
static void out_amount(i128 v, int scale) {
  i128 unit = p10(SC - scale), q, f;
  char b[16];
  int i;
  if (v < 0) {
    outc('-');
    v = -v;
  }
  v /= unit;
  q = v / p10(scale);
  f = v % p10(scale);
  out_int(q);
  if (scale == 0)
    return;
  outc('.');
  for (i = scale - 1; i >= 0; i--) {
    b[i] = (char)('0' + (int)(f % 10));
    f /= 10;
  }
  out(b, (size_t)scale);
}

/* ------------------------------------------------------------ interned names */

typedef struct {
  char **name;
  int *len;
  int n, cap;
  int *tab; /* id + 1, 0 = empty */
  int tcap;
} Pool;

static uint32_t hash(const char *s, int n) {
  uint32_t h = 2166136261u;
  while (n-- > 0)
    h = (h ^ (unsigned char)*s++) * 16777619u;
  return h;
}

static void pool_rehash(Pool *p) {
  int i, ncap = p->tcap ? p->tcap * 2 : 256;
  free(p->tab);
  p->tab = calloc((size_t)ncap, sizeof *p->tab);
  if (!p->tab)
    die("out of memory");
  p->tcap = ncap;
  for (i = 0; i < p->n; i++) {
    uint32_t h = hash(p->name[i], p->len[i]) & (uint32_t)(ncap - 1);
    while (p->tab[h])
      h = (h + 1) & (uint32_t)(ncap - 1);
    p->tab[h] = i + 1;
  }
}

static int pool_get(Pool *p, const char *s, int n) {
  uint32_t h;
  if ((p->n + 1) * 2 > p->tcap)
    pool_rehash(p);
  h = hash(s, n) & (uint32_t)(p->tcap - 1);
  while (p->tab[h]) {
    int id = p->tab[h] - 1;
    if (p->len[id] == n && memcmp(p->name[id], s, (size_t)n) == 0)
      return id;
    h = (h + 1) & (uint32_t)(p->tcap - 1);
  }
  if (p->n >= p->cap) {
    p->cap = p->cap ? p->cap * 2 : 64;
    p->name = xrealloc(p->name, (size_t)p->cap * sizeof *p->name);
    p->len = xrealloc(p->len, (size_t)p->cap * sizeof *p->len);
  }
  p->name[p->n] = xrealloc(NULL, (size_t)n + 1);
  memcpy(p->name[p->n], s, (size_t)n);
  p->name[p->n][n] = 0;
  p->len[p->n] = n;
  p->tab[h] = p->n + 1;
  return p->n++;
}

static Pool accts, coms;

/* ------------------------------------------------------------ lexical rules */

typedef struct {
  const char *s;
  int n;
} Tok;

static int tok_is(Tok t, const char *lit) {
  return t.n == (int)strlen(lit) && memcmp(t.s, lit, (size_t)t.n) == 0;
}

static int is_digit(char c) { return c >= '0' && c <= '9'; }

static int date_shape(Tok t) {
  int i;
  if (t.n != 10 || t.s[4] != '-' || t.s[7] != '-')
    return 0;
  for (i = 0; i < 10; i++)
    if (i != 4 && i != 7 && !is_digit(t.s[i]))
      return 0;
  return 1;
}

static int num(const char *s, int n) {
  int v = 0;
  while (n-- > 0)
    v = v * 10 + (*s++ - '0');
  return v;
}

/* A date-shaped token as yyyymmdd, or 0 when the date does not exist. */
static int date_value(Tok t) {
  static const int mdays[] = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31};
  int y = num(t.s, 4), m = num(t.s + 5, 2), d = num(t.s + 8, 2), dim;
  if (y == 0 || m < 1 || m > 12 || d < 1)
    return 0;
  dim = mdays[m - 1];
  if (m == 2 && ((y % 4 == 0 && y % 100 != 0) || y % 400 == 0))
    dim = 29;
  if (d > dim)
    return 0;
  return y * 10000 + m * 100 + d;
}

static int seg_char(char c) {
  return (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') || is_digit(c) ||
         c == '-' || c == '_';
}

static int account_ok(Tok t) {
  int i, seg = 0;
  if (t.n == 0)
    return 0;
  for (i = 0; i < t.n; i++) {
    if (t.s[i] == ':') {
      if (seg == 0)
        return 0;
      seg = 0;
    } else if (seg_char(t.s[i])) {
      seg++;
    } else {
      return 0;
    }
  }
  return seg > 0;
}

static int commodity_ok(Tok t) {
  int i;
  if (t.n < 1 || t.n > 10)
    return 0;
  for (i = 0; i < t.n; i++)
    if (t.s[i] < 'A' || t.s[i] > 'Z')
      return 0;
  return 1;
}

/* An amount literal: mantissa and decimals. Returns 0 when malformed. */
static int amount_lit(Tok t, int64_t *m, int *dec) {
  int i = 0, ip = 0, fp = 0, neg = 0;
  int64_t v = 0;
  if (i < t.n && t.s[i] == '-') {
    neg = 1;
    i++;
  }
  while (i < t.n && is_digit(t.s[i])) {
    v = v * 10 + (t.s[i++] - '0');
    ip++;
  }
  if (ip < 1 || ip > 10)
    return 0;
  if (i < t.n && t.s[i] == '.') {
    i++;
    while (i < t.n && is_digit(t.s[i])) {
      v = v * 10 + (t.s[i++] - '0');
      fp++;
    }
    if (fp < 1 || fp > 6)
      return 0;
  }
  if (i != t.n)
    return 0;
  *m = neg ? -v : v;
  *dec = fp;
  return 1;
}

static int *com_scale;
static int com_scale_cap;

static void see_scale(int com, int dec) {
  while (com >= com_scale_cap) {
    int old = com_scale_cap;
    com_scale_cap = com_scale_cap ? com_scale_cap * 2 : 16;
    com_scale = xrealloc(com_scale, (size_t)com_scale_cap * sizeof *com_scale);
    memset(com_scale + old, 0, (size_t)(com_scale_cap - old) * sizeof *com_scale);
  }
  if (dec > com_scale[com])
    com_scale[com] = dec;
}

static int scale_of(int com) { return com < com_scale_cap ? com_scale[com] : 0; }

/* Decimals needed to write v (10^-12 units) exactly. */
static int decimals_of(i128 v) {
  int d = SC;
  if (v < 0)
    v = -v;
  while (d > 0 && v % 10 == 0) {
    v /= 10;
    d--;
  }
  return d;
}

/* ------------------------------------------------------------ journal model */

typedef struct {
  int line, acct;
  int has_amt, com;
  i128 amt;
  int has_cost, wcom;
  i128 w; /* weight */
  int has_assert, acom;
  i128 aamt;
} Posting;

typedef struct {
  int line, date;
  int first, np; /* valid postings */
  int nlines;    /* posting lines, valid or not */
  int bad;       /* stage 1 failed */
} Txn;

typedef struct {
  int date, acct, com, seq, line;
  i128 amt;
} Entry;

typedef struct {
  int date, base, quote;
  int64_t m;
  int dec;
} Price;

typedef struct {
  int line;
  const char *code;
} Err;

static Posting *posts;
static int npost, cappost;
static Txn *txns;
static int ntxn, captxn;
static Entry *ents;
static int nent, capent;
static Price *prices;
static int nprice, capprice;
static Err *errs;
static int nerr, caperr;
static int *open_date, *close_date, dir_cap;

typedef struct {
  int pidx, date;
} Pending;
static Pending *pend;
static int npend, cappend;

static void err(int line, const char *code) {
  GROW(errs, nerr, caperr);
  errs[nerr].line = line;
  errs[nerr].code = code;
  nerr++;
}

static void dir_room(int acct) {
  while (acct >= dir_cap) {
    int old = dir_cap;
    dir_cap = dir_cap ? dir_cap * 2 : 64;
    open_date = xrealloc(open_date, (size_t)dir_cap * sizeof *open_date);
    close_date = xrealloc(close_date, (size_t)dir_cap * sizeof *close_date);
    memset(open_date + old, 0, (size_t)(dir_cap - old) * sizeof *open_date);
    memset(close_date + old, 0, (size_t)(dir_cap - old) * sizeof *close_date);
  }
}

/* ------------------------------------------------------------ parsing */

static int tokenize(const char *s, int n, Tok *t) {
  int i = 0, k = 0;
  while (i < n) {
    int j;
    while (i < n && (s[i] == ' ' || s[i] == '\t'))
      i++;
    if (i >= n)
      break;
    j = i;
    while (j < n && s[j] != ' ' && s[j] != '\t')
      j++;
    if (k < MAXTOK) {
      t[k].s = s + i;
      t[k].n = j - i;
    }
    k++;
    i = j;
  }
  return k;
}

/* Parses one posting line into posts[npost]; returns 0 when malformed. */
static int parse_posting(Tok *t, int nt, int line) {
  Posting p;
  int i = 1, dec;
  int64_t m;
  memset(&p, 0, sizeof p);
  p.line = line;
  if (nt > MAXTOK || !account_ok(t[0]))
    return 0;
  if (i < nt && !tok_is(t[i], "=")) {
    if (i + 1 >= nt || !amount_lit(t[i], &m, &dec) || !commodity_ok(t[i + 1]))
      return 0;
    p.has_amt = 1;
    p.com = pool_get(&coms, t[i + 1].s, t[i + 1].n);
    see_scale(p.com, dec);
    p.amt = (i128)m * p10(SC - dec);
    p.wcom = p.com;
    p.w = p.amt;
    i += 2;
    if (i < nt && tok_is(t[i], "@")) {
      int64_t cm;
      int cdec;
      if (i + 2 >= nt || !amount_lit(t[i + 1], &cm, &cdec) ||
          !commodity_ok(t[i + 2]))
        return 0;
      p.has_cost = 1;
      p.wcom = pool_get(&coms, t[i + 2].s, t[i + 2].n);
      see_scale(p.wcom, cdec);
      p.w = (i128)m * cm * p10(SC - dec - cdec);
      i += 3;
    }
  }
  if (i < nt && tok_is(t[i], "=")) {
    if (i + 2 >= nt || !amount_lit(t[i + 1], &m, &dec) ||
        !commodity_ok(t[i + 2]))
      return 0;
    p.has_assert = 1;
    p.acom = pool_get(&coms, t[i + 2].s, t[i + 2].n);
    see_scale(p.acom, dec);
    p.aamt = (i128)m * p10(SC - dec);
    i += 3;
  }
  if (i != nt)
    return 0;
  p.acct = pool_get(&accts, t[0].s, t[0].n);
  GROW(posts, npost, cappost);
  posts[npost++] = p;
  return 1;
}

static void directive(Tok *t, int nt, int line) {
  int d, acct, is_open = tok_is(t[1], "open");
  int *slot;
  if (nt != 3 || !date_shape(t[0]) || !account_ok(t[2])) {
    err(line, "PARSE");
    return;
  }
  d = date_value(t[0]);
  if (!d) {
    err(line, "BAD_DATE");
    return;
  }
  acct = pool_get(&accts, t[2].s, t[2].n);
  dir_room(acct);
  slot = is_open ? &open_date[acct] : &close_date[acct];
  if (*slot) {
    err(line, "DUPLICATE");
    return;
  }
  *slot = d;
}

static void price(Tok *t, int nt, int line) {
  Price p;
  if (nt != 5 || !date_shape(t[1]) || !commodity_ok(t[2]) ||
      !amount_lit(t[3], &p.m, &p.dec) || !commodity_ok(t[4]) ||
      (t[2].n == t[4].n && memcmp(t[2].s, t[4].s, (size_t)t[2].n) == 0)) {
    err(line, "PARSE");
    return;
  }
  p.date = date_value(t[1]);
  if (!p.date) {
    err(line, "BAD_DATE");
    return;
  }
  p.base = pool_get(&coms, t[2].s, t[2].n);
  p.quote = pool_get(&coms, t[4].s, t[4].n);
  see_scale(p.quote, p.dec);
  GROW(prices, nprice, capprice);
  prices[nprice++] = p;
}

enum { NONE, IN_TXN, SKIP };

static void end_txn(int *state) {
  if (*state == IN_TXN && txns[ntxn - 1].nlines == 0) {
    err(txns[ntxn - 1].line, "PARSE");
    txns[ntxn - 1].bad = 1;
  }
  *state = NONE;
}

static void parse(const char *buf, size_t len) {
  size_t pos = 0;
  int line = 0, state = NONE;
  Tok t[MAXTOK];
  while (pos < len) {
    const char *s = buf + pos, *nl = memchr(s, '\n', len - pos);
    int n = nl ? (int)(nl - s) : (int)(len - pos), nt, d;
    const char *semi;
    pos += (size_t)n + (nl ? 1 : 0);
    line++;
    semi = memchr(s, ';', (size_t)n);
    if (semi)
      n = (int)(semi - s);
    while (n > 0 && (s[n - 1] == ' ' || s[n - 1] == '\t'))
      n--;
    if (n == 0) {
      end_txn(&state);
      continue;
    }
    nt = tokenize(s, n, t);
    if (s[0] == ' ' || s[0] == '\t') {
      if (state == SKIP)
        continue;
      if (state == NONE) {
        err(line, "PARSE");
        continue;
      }
      txns[ntxn - 1].nlines++;
      if (parse_posting(t, nt, line)) {
        txns[ntxn - 1].np++;
      } else {
        err(line, "PARSE");
        txns[ntxn - 1].bad = 1;
      }
      continue;
    }
    end_txn(&state);
    if (is_digit(s[0])) {
      if (nt >= 2 && (tok_is(t[1], "open") || tok_is(t[1], "close"))) {
        directive(t, nt, line);
        continue;
      }
      if (!date_shape(t[0])) {
        err(line, "PARSE");
        state = SKIP;
        continue;
      }
      d = date_value(t[0]);
      if (!d) {
        err(line, "BAD_DATE");
        state = SKIP;
        continue;
      }
      GROW(txns, ntxn, captxn);
      txns[ntxn].line = line;
      txns[ntxn].date = d;
      txns[ntxn].first = npost;
      txns[ntxn].np = 0;
      txns[ntxn].nlines = 0;
      txns[ntxn].bad = 0;
      ntxn++;
      state = IN_TXN;
    } else if (s[0] == 'P' && n > 1 && (s[1] == ' ' || s[1] == '\t')) {
      price(t, nt, line);
    } else {
      err(line, "PARSE");
    }
  }
  end_txn(&state);
}

/* ------------------------------------------------------------ validation */

typedef struct {
  int com;
  i128 amt;
} Res;

static Res *rs;
static int caprs;

static int com_cmp(int a, int b) {
  return strcmp(coms.name[a], coms.name[b]);
}

static void add_entry(const Txn *tx, const Posting *p, int com, i128 amt) {
  GROW(ents, nent, capent);
  ents[nent].date = tx->date;
  ents[nent].acct = p->acct;
  ents[nent].com = com;
  ents[nent].amt = amt;
  ents[nent].line = p->line;
  ents[nent].seq = nent;
  nent++;
}

/* Stage 2. Returns 1 when it reported an error; otherwise adds the entries. */
static int stage_balance(const Txn *tx) {
  int i, j, nrs = 0, nel = 0;
  if (tx->np > caprs) {
    caprs = tx->np;
    rs = xrealloc(rs, (size_t)caprs * sizeof *rs);
  }
  for (i = tx->first; i < tx->first + tx->np; i++) {
    const Posting *p = &posts[i];
    if (!p->has_amt) {
      nel++;
      continue;
    }
    for (j = 0; j < nrs && rs[j].com != p->wcom; j++)
      ;
    if (j == nrs) {
      rs[nrs].com = p->wcom;
      rs[nrs].amt = 0;
      nrs++;
    }
    rs[j].amt += p->w;
  }
  if (nel >= 2) {
    err(tx->line, "MULTI_ELIDED");
    return 1;
  }
  if (nel == 0) {
    for (j = 0; j < nrs; j++)
      if (rs[j].amt != 0) {
        err(tx->line, "UNBALANCED");
        return 1;
      }
  }
  /* Residual commodities in name order: the elided posting's amounts. */
  for (i = 1; i < nrs; i++)
    for (j = i; j > 0 && com_cmp(rs[j - 1].com, rs[j].com) > 0; j--) {
      Res tmp = rs[j];
      rs[j] = rs[j - 1];
      rs[j - 1] = tmp;
    }
  for (i = tx->first; i < tx->first + tx->np; i++) {
    const Posting *p = &posts[i];
    if (p->has_amt) {
      add_entry(tx, p, p->com, p->amt);
      continue;
    }
    for (j = 0; j < nrs; j++) {
      i128 amt = -rs[j].amt;
      if (amt == 0)
        continue;
      see_scale(rs[j].com, decimals_of(amt));
      add_entry(tx, p, rs[j].com, amt);
    }
  }
  return 0;
}

/* Stage 3. Returns 1 when any posting reported an error. */
static int stage_accounts(const Txn *tx) {
  int i, bad = 0;
  for (i = tx->first; i < tx->first + tx->np; i++) {
    const Posting *p = &posts[i];
    int od, cd;
    dir_room(p->acct);
    od = open_date[p->acct];
    cd = close_date[p->acct];
    if (!od || od > tx->date) {
      err(p->line, "NOT_OPEN");
      bad = 1;
    } else if (cd && cd < tx->date) {
      err(p->line, "CLOSED");
      bad = 1;
    }
  }
  return bad;
}

static void queue_assertions(const Txn *tx) {
  int i;
  for (i = tx->first; i < tx->first + tx->np; i++)
    if (posts[i].has_assert) {
      GROW(pend, npend, cappend);
      pend[npend].pidx = i;
      pend[npend].date = tx->date;
      npend++;
    }
}

static int ent_key_cmp(const void *a, const void *b) {
  const Entry *x = &ents[*(const int *)a], *y = &ents[*(const int *)b];
  if (x->acct != y->acct)
    return x->acct < y->acct ? -1 : 1;
  if (x->com != y->com)
    return x->com < y->com ? -1 : 1;
  if (x->date != y->date)
    return x->date < y->date ? -1 : 1;
  return x->seq - y->seq;
}

/* An entry ranks at or before the assertion's cut: (acct, com) first, then the date. */
static int within(const Entry *en, int acct, int com, int d) {
  if (en->acct != acct)
    return en->acct < acct;
  if (en->com != com)
    return en->com < com;
  return en->date <= d;
}

static int before_group(const Entry *en, int acct, int com) {
  if (en->acct != acct)
    return en->acct < acct;
  return en->com < com;
}

static void check_assertions(void) {
  int *ord, i;
  i128 *pre;
  if (npend == 0)
    return;
  ord = xrealloc(NULL, (size_t)nent * sizeof *ord);
  pre = xrealloc(NULL, ((size_t)nent + 1) * sizeof *pre);
  for (i = 0; i < nent; i++)
    ord[i] = i;
  qsort(ord, (size_t)nent, sizeof *ord, ent_key_cmp);
  pre[0] = 0;
  for (i = 0; i < nent; i++)
    pre[i + 1] = pre[i] + ents[ord[i]].amt;
  for (i = 0; i < npend; i++) {
    const Posting *p = &posts[pend[i].pidx];
    int lo = 0, hi = nent, a, b;
    while (lo < hi) {
      int mid = (lo + hi) / 2;
      if (before_group(&ents[ord[mid]], p->acct, p->acom))
        lo = mid + 1;
      else
        hi = mid;
    }
    a = lo;
    hi = nent;
    while (lo < hi) {
      int mid = (lo + hi) / 2;
      if (within(&ents[ord[mid]], p->acct, p->acom, pend[i].date))
        lo = mid + 1;
      else
        hi = mid;
    }
    b = lo;
    if (pre[b] - pre[a] != p->aamt)
      err(p->line, "ASSERT_FAILED");
  }
  free(ord);
  free(pre);
}

static int err_cmp(const void *a, const void *b) {
  const Err *x = a, *y = b;
  return x->line - y->line;
}

static void validate(void) {
  int t;
  for (t = 0; t < ntxn; t++) {
    const Txn *tx = &txns[t];
    if (tx->bad)
      continue;
    if (stage_balance(tx) || stage_accounts(tx))
      continue;
    queue_assertions(tx);
  }
  check_assertions();
  qsort(errs, (size_t)nerr, sizeof *errs, err_cmp);
}

static void print_errors(void) {
  int i;
  for (i = 0; i < nerr; i++) {
    char b[32];
    snprintf(b, sizeof b, "%d: ", errs[i].line);
    outs(b);
    outs(errs[i].code);
    outc('\n');
  }
}

/* ------------------------------------------------------------ reports */

static int *parent, *depth;

/* Interns every ancestor of every account; fills parent[] and depth[]. */
static void build_tree(void) {
  int a, n0 = accts.n;
  for (a = 0; a < n0; a++) {
    int k;
    for (k = 0; k < accts.len[a]; k++)
      if (accts.name[a][k] == ':')
        pool_get(&accts, accts.name[a], k);
  }
  parent = xrealloc(NULL, (size_t)accts.n * sizeof *parent);
  depth = xrealloc(NULL, (size_t)accts.n * sizeof *depth);
  for (a = 0; a < accts.n; a++) {
    int k = accts.len[a], d = 1, i;
    while (k > 0 && accts.name[a][k - 1] != ':')
      k--;
    parent[a] = k > 0 ? pool_get(&accts, accts.name[a], k - 1) : -1;
    for (i = 0; i < accts.len[a]; i++)
      if (accts.name[a][i] == ':')
        d++;
    depth[a] = d;
  }
}

/* Segment by segment, bytewise: ':' sorts below every name character. */
static int acct_cmp(const void *a, const void *b) {
  const unsigned char *x = (const unsigned char *)accts.name[*(const int *)a];
  const unsigned char *y = (const unsigned char *)accts.name[*(const int *)b];
  for (;; x++, y++) {
    int cx = *x == ':' ? 1 : *x, cy = *y == ':' ? 1 : *y;
    if (cx != cy)
      return cx - cy;
    if (!cx)
      return 0;
  }
}

static int com_sort_cmp(const void *a, const void *b) {
  return com_cmp(*(const int *)a, *(const int *)b);
}

/* |v| * |m| / 10^dec rounded to `scale` decimals, half away from zero; signed. */
static i128 convert(i128 v, int64_t m, int dec, int scale) {
  int neg = (v < 0) != (m < 0);
  i128 am = m < 0 ? -(i128)m : m, av = v < 0 ? -v : v;
  i128 q = av / p10(dec), r = av % p10(dec);
  i128 prod = q * am + (r * am) / p10(dec), rr = (r * am) % p10(dec);
  i128 unit = p10(SC - scale), rem = prod % unit;
  prod -= rem;
  if (2 * (rem * p10(dec) + rr) >= unit * p10(dec))
    prod += unit;
  return neg ? -prod : prod;
}

typedef struct {
  int depth, has_end, end, value;
  const char *prefix;
} Opts;

static void balance(const Opts *o) {
  int A, C, a, c, i, *ord, *cord, ncord = 0, missing = 0;
  i128 *tot;
  int *pidx = NULL;
  build_tree();
  A = accts.n;
  C = coms.n;
  tot = calloc((size_t)A * (size_t)(C ? C : 1), sizeof *tot);
  if (!tot)
    die("out of memory");
  for (i = 0; i < nent; i++) {
    const Entry *e = &ents[i];
    if (o->has_end && e->date > o->end)
      continue;
    tot[(size_t)e->acct * C + e->com] += e->amt;
  }
  /* Roll each account into its parent, deepest accounts first. */
  {
    int maxd = 0, d;
    for (a = 0; a < A; a++)
      if (depth[a] > maxd)
        maxd = depth[a];
    for (d = maxd; d > 1; d--)
      for (a = 0; a < A; a++)
        if (depth[a] == d)
          for (c = 0; c < C; c++)
            tot[(size_t)parent[a] * C + c] += tot[(size_t)a * C + c];
  }
  ord = xrealloc(NULL, (size_t)A * sizeof *ord);
  for (a = 0; a < A; a++)
    ord[a] = a;
  qsort(ord, (size_t)A, sizeof *ord, acct_cmp);
  cord = xrealloc(NULL, (size_t)(C ? C : 1) * sizeof *cord);
  for (c = 0; c < C; c++)
    cord[ncord++] = c;
  qsort(cord, (size_t)ncord, sizeof *cord, com_sort_cmp);

  if (o->value >= 0) {
    int cur = o->value;
    pidx = xrealloc(NULL, (size_t)(C ? C : 1) * sizeof *pidx);
    for (c = 0; c < C; c++) {
      int best = -1;
      pidx[c] = -1;
      if (c == cur)
        continue;
      for (i = 0; i < nprice; i++) {
        const Price *pr = &prices[i];
        if (pr->base != c || pr->quote != cur)
          continue;
        if (o->has_end && pr->date > o->end)
          continue;
        if (best < 0 || pr->date >= prices[best].date)
          best = i;
      }
      pidx[c] = best;
    }
    /* Commodities that a printed account must convert but cannot. */
    for (i = 0; i < ncord; i++) {
      c = cord[i];
      if (c == cur || pidx[c] >= 0)
        continue;
      for (a = 0; a < A; a++)
        if (depth[a] <= o->depth && tot[(size_t)a * C + c] != 0) {
          outs("NO_PRICE ");
          outs(coms.name[c]);
          outc('\n');
          missing = 1;
          break;
        }
    }
    if (missing)
      return;
  }

  for (i = 0; i < A; i++) {
    a = ord[i];
    if (depth[a] > o->depth)
      continue;
    if (o->value >= 0) {
      int cur = o->value, k;
      i128 sum = 0;
      for (k = 0; k < ncord; k++) {
        i128 v;
        c = cord[k];
        v = tot[(size_t)a * C + c];
        if (v == 0)
          continue;
        if (c == cur)
          sum += v;
        else
          sum += convert(v, prices[pidx[c]].m, prices[pidx[c]].dec,
                         scale_of(cur));
      }
      if (sum == 0)
        continue;
      outs(accts.name[a]);
      outc(' ');
      out_amount(sum, scale_of(cur));
      outc(' ');
      outs(coms.name[cur]);
      outc('\n');
      continue;
    }
    for (c = 0; c < ncord; c++) {
      i128 v = tot[(size_t)a * C + cord[c]];
      if (v == 0)
        continue;
      outs(accts.name[a]);
      outc(' ');
      out_amount(v, scale_of(cord[c]));
      outc(' ');
      outs(coms.name[cord[c]]);
      outc('\n');
    }
  }
}

static int reg_cmp(const void *a, const void *b) {
  const Entry *x = &ents[*(const int *)a], *y = &ents[*(const int *)b];
  if (x->date != y->date)
    return x->date < y->date ? -1 : 1;
  return x->seq - y->seq;
}

static int matches(int acct, const char *prefix) {
  size_t n = strlen(prefix);
  const char *name = accts.name[acct];
  return strncmp(name, prefix, n) == 0 && (name[n] == 0 || name[n] == ':');
}

static void out_date(int d) {
  char b[16];
  snprintf(b, sizeof b, "%04d-%02d-%02d", d / 10000, d / 100 % 100, d % 100);
  outs(b);
}

static void reg(const Opts *o) {
  int *sel, n = 0, i, a;
  char *match = xrealloc(NULL, (size_t)(accts.n ? accts.n : 1));
  i128 *run = calloc((size_t)(coms.n ? coms.n : 1), sizeof *run);
  if (!run)
    die("out of memory");
  for (a = 0; a < accts.n; a++)
    match[a] = (char)matches(a, o->prefix);
  sel = xrealloc(NULL, (size_t)(nent ? nent : 1) * sizeof *sel);
  for (i = 0; i < nent; i++)
    if (match[ents[i].acct])
      sel[n++] = i;
  qsort(sel, (size_t)n, sizeof *sel, reg_cmp);
  for (i = 0; i < n; i++) {
    const Entry *e = &ents[sel[i]];
    int s = scale_of(e->com);
    run[e->com] += e->amt;
    out_date(e->date);
    outc(' ');
    outs(accts.name[e->acct]);
    outc(' ');
    out_amount(e->amt, s);
    outc(' ');
    outs(coms.name[e->com]);
    outc(' ');
    out_amount(run[e->com], s);
    outc(' ');
    outs(coms.name[e->com]);
    outc('\n');
  }
}

/* ------------------------------------------------------------ main */

static int usage(void) {
  outs("USAGE\n");
  flush();
  return 0;
}

static Tok arg_tok(const char *s) {
  Tok t;
  t.s = s;
  t.n = (int)strlen(s);
  return t;
}

static int positive_int(const char *s, int *v) {
  long n = 0;
  if (!*s)
    return 0;
  for (; *s; s++) {
    if (!is_digit(*s))
      return 0;
    if (n < 100000000)
      n = n * 10 + (*s - '0');
  }
  if (n < 1)
    return 0;
  *v = (int)n;
  return 1;
}

static char *read_all(size_t *len) {
  size_t cap = 1 << 20, n = 0, r;
  char *b = xrealloc(NULL, cap);
  while ((r = fread(b + n, 1, cap - n, stdin)) > 0) {
    n += r;
    if (n == cap) {
      cap *= 2;
      b = xrealloc(b, cap);
    }
  }
  *len = n;
  return b;
}

int main(int argc, char **argv) {
  Opts o;
  const char *value = NULL;
  int cmd, i, seen_depth = 0, seen_end = 0;
  size_t len;
  char *buf;
  memset(&o, 0, sizeof o);
  o.depth = 1 << 30;
  o.value = -1;
  if (argc < 2)
    return usage();
  if (strcmp(argv[1], "check") == 0) {
    cmd = 0;
    if (argc != 2)
      return usage();
  } else if (strcmp(argv[1], "balance") == 0) {
    cmd = 1;
    for (i = 2; i < argc; i += 2) {
      if (i + 1 >= argc)
        return usage();
      if (strcmp(argv[i], "--depth") == 0) {
        if (seen_depth++ || !positive_int(argv[i + 1], &o.depth))
          return usage();
      } else if (strcmp(argv[i], "--end") == 0) {
        Tok t = arg_tok(argv[i + 1]);
        if (seen_end++ || !date_shape(t) || !(o.end = date_value(t)))
          return usage();
        o.has_end = 1;
      } else if (strcmp(argv[i], "--value") == 0) {
        if (value || !commodity_ok(arg_tok(argv[i + 1])))
          return usage();
        value = argv[i + 1];
      } else {
        return usage();
      }
    }
  } else if (strcmp(argv[1], "register") == 0) {
    cmd = 2;
    if (argc != 3 || !account_ok(arg_tok(argv[2])))
      return usage();
    o.prefix = argv[2];
  } else {
    return usage();
  }

  buf = read_all(&len);
  parse(buf, len);
  validate();
  if (nerr > 0) {
    print_errors();
  } else if (cmd == 0) {
    outs("OK\n");
  } else if (cmd == 1) {
    if (value)
      o.value = pool_get(&coms, value, (int)strlen(value));
    balance(&o);
  } else {
    reg(&o);
  }
  flush();
  return 0;
}
