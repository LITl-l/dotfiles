# assert-early: an assertion counts the postings of its own date only up to itself in
# file order, not every posting of that date.
/^static int within(/i\
static int cut_seq;
s/^  return en->date <= d;$/  return en->date < d || (en->date == d \&\& en->seq <= cut_seq);/
/^    a = lo;$/a\
    cut_seq = -1;\
    for (int k = 0; k < nent; k++)\
      if (ents[k].line == p->line)\
        cut_seq = ents[k].seq;
