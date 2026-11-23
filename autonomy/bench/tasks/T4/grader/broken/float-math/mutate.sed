# float-math: the balancing check sums weights as binary floating point in units, so
# 0.1 + 0.2 - 0.3 is not zero and a balanced transaction reports UNBALANCED.
/^  int com;$/a\
  double f;
/^      rs\[nrs\]\.amt = 0;$/a\
      rs[nrs].f = 0;
/^    rs\[j\]\.amt += p->w;$/a\
    rs[j].f += (double)p->w / 1e12;
s/^      if (rs\[j\]\.amt != 0) {$/      if (rs[j].f != 0.0) {/
