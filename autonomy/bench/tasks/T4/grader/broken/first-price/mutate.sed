# first-price: --value uses the oldest eligible price instead of the latest.
s/^        if (best < 0 || pr->date >= prices\[best\]\.date)$/        if (best < 0 || pr->date < prices[best].date)/
