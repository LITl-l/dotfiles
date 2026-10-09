---- MODULE Settings ----
(* UC-01 save flow, including network failure and retry.
   Checks rule R-02 (trs.yaml rules[].tla) and the AC witness with TLC.
   Invariants named Inv_... are owned by humans. Next may be drafted by an AI,
   but every AC that relies on this model must have a witness that TLC violates.
   NOTE: SANY accepts ASCII only, even in comments. Keep Japanese in trs.yaml. *)
VARIABLES ui, draft, saved, hadError
vars == <<ui, draft, saved, hadError>>

TypeOK ==
  /\ ui \in {"editing", "saving", "error", "done"}
  /\ draft \in {"empty", "edited"}
  /\ saved \in BOOLEAN
  /\ hadError \in BOOLEAN

Init == ui = "editing" /\ draft = "empty" /\ saved = FALSE /\ hadError = FALSE

Edit     == ui = "editing" /\ draft' = "edited" /\ UNCHANGED <<ui, saved, hadError>>
Save     == ui = "editing" /\ draft = "edited" /\ ui' = "saving" /\ UNCHANGED <<draft, saved, hadError>>
Succeed  == ui = "saving" /\ ui' = "done" /\ saved' = TRUE /\ UNCHANGED <<draft, hadError>>
Fail     == ui = "saving" /\ ui' = "error" /\ hadError' = TRUE /\ UNCHANGED <<draft, saved>>
Retry    == ui = "error" /\ ui' = "saving" /\ UNCHANGED <<draft, saved, hadError>>
Finished == ui = "done" /\ UNCHANGED vars

Next == Edit \/ Save \/ Succeed \/ Fail \/ Retry \/ Finished
Spec == Init /\ [][Next]_vars

\* R-02: on network failure, keep the draft and show an error
Inv_KeepDraftOnError == ui = "error" => draft = "edited"

\* Witness (must be VIOLATED): "a save after a failure is never reached"
Witness_RetrySaved == ~(hadError /\ saved)
====
