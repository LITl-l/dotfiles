# An escaped brace keeps its backslash: \{x\} renders as \{x\} instead of {x}.
s/text\.extend(chars\.next());/text.push('\\\\'); text.extend(chars.next());/
