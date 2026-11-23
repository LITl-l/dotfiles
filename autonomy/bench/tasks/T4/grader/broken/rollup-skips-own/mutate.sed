# rollup-skips-own: a parent's balance is only the sum of its children; what was posted
# to the parent itself is dropped.
/^  \/\* Roll each account into its parent, deepest accounts first\. \*\/$/i\
  for (a = 0; a < A; a++)\
    if (parent[a] >= 0)\
      for (c = 0; c < C; c++)\
        tot[(size_t)parent[a] * C + c] = 0;
