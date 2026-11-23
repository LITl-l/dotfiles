# unstable-day: register orders postings of the same date against file order.
/^static int reg_cmp(/,/^}$/s/^  return x->seq - y->seq;$/  return y->seq - x->seq;/
