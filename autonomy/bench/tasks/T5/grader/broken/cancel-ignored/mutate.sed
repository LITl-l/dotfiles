# {} is treated as an unknown meta: pending attach, case and glue survive it.
s/"" => self\.cancel(),/"" => {}/
