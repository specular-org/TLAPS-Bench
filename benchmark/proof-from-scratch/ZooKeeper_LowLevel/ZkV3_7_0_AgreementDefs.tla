------------------------ MODULE ZkV3_7_0_AgreementDefs ------------------------

EXTENDS ZkV3_7_0Model

TxnEqual(txn1, txn2) == /\ ZxidEqual(txn1.zxid, txn2.zxid)
                        /\ txn1.value = txn2.value

Agreement == \A i, j \in Server:
                /\ IsFollower(i) /\ Len(confirmedHistory[i]) > 0
                /\ IsFollower(j) /\ Len(confirmedHistory[j]) > 0
                =>
                \A idx1 \in 1..Len(confirmedHistory[i]), idx2 \in 1..Len(confirmedHistory[j]) :
                    \/ \E idx_j \in 1..Len(confirmedHistory[j]):
                        TxnEqual(confirmedHistory[j][idx_j], confirmedHistory[i][idx1])
                    \/ \E idx_i \in 1..Len(confirmedHistory[i]):
                        TxnEqual(confirmedHistory[i][idx_i], confirmedHistory[j][idx2])

=============================================================================
