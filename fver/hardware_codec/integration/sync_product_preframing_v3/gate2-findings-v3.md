# Gate 2 finding closure ledger

The one independent Gate 2 review found no encoder correctness defect and no
test-gaming. This ledger records only the bounded mechanical closure; no new
independent review follows it.

| Original finding | Version-three mechanical closure |
|---|---|
| Every mode did not authenticate its contract | The common checker guard and the derivation program require correction-contract SHA-256 `5fbbd340cc1661b7be2e48a63656593b467dbdc84333da388656879731c30d3c` before any v3 pass marker. |
| Four pre-correction RTL identities were not separately pinned | The checker requires the four exact contract hashes and the byte-identical 25-row current-product seal before and after execution. |
| GREEN did not execute all structural controls | GREEN invokes the five inherited, three closure, and one ownership-shell multiplicity controls and requires `structural_controls=9`. |
| Two inherited plants were reachability assertions | The seal-validated derivation replaces only those direct failures with a force on `sync_product_rst_n` and a force coupling `bottom_record_valid` to `top_record_valid`; exact derived SHA-256 is `d19854f4e38eada4b7edf2ec137f56159ce97610ec05f22ce720a8169e4f633c`. |
| Evidence programs and nine core-plant logs were not pinned/proved | The 37-row evidence seal pins every cited program; GREEN invokes the qualified runner and independently validates the unplanted 3,096-case log plus nine distinct actual planted logs. |
| Ownership-shell count was dropped | Structure, structural self-test, and final markers require exactly one `opendvs_sync_mode_ownership_shell i_sync_mode_ownership`. |

The package preserves the honest evidence boundary: no sealed v1 execution
transcript exists, v2 GREEN is the historical mechanical result, and v3 adds
only verification controls over unchanged production.
