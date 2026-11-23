# prefix-substring: register matches PREFIX as a string prefix, so Assets-Old matches Assets.
s/^  return strncmp(name, prefix, n) == 0 && (name\[n\] == 0 || name\[n\] == ':');$/  return strncmp(name, prefix, n) == 0;/
