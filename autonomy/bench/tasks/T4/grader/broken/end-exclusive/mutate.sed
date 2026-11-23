# end-exclusive: balance --end DATE leaves out the postings dated DATE.
s/^    if (o->has_end && e->date > o->end)$/    if (o->has_end \&\& e->date >= o->end)/
