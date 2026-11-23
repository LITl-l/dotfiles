# bytewise-order: balance orders accounts by their whole name, bytewise, so Assets-Old
# comes between Assets and Assets:Cash.
s/^    int cx = \*x == ':' ? 1 : \*x, cy = \*y == ':' ? 1 : \*y;$/    int cx = *x, cy = *y;/
