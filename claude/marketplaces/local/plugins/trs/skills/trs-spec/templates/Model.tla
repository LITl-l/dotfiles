---- MODULE Model ----
(* ASCII only (SANY rejects non-ASCII even in comments).
   Do not write the two-character comment terminator inside a comment.
   Human-owned: TypeOK and every Inv_ definition referenced by trs.yaml rules[].tla.
   AI-draftable: Init / actions / Next. Every AC with tla_witness proves reachability. *)
VARIABLES state
vars == <<state>>

TypeOK == state \in {"start", "done"}

Init == state = "start"

Finish == state = "start" /\ state' = "done"
Stay   == state = "done" /\ UNCHANGED vars

Next == Finish \/ Stay
Spec == Init /\ [][Next]_vars

\* Rule R-xx (EARS): replace with the human-owned invariant
Inv_Example == TRUE

\* Witness for AC-xxx: must be VIOLATED by TLC (= the AC postcondition is reachable)
Witness_Example == ~(state = "done")
====
