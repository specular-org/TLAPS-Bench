------------------------ MODULE ZkV3_7_0_GlobalPrimaryOrderDefs ------------------------

EXTENDS ZkV3_7_0Model

EpochPrecedeInTxn(txn1, txn2) == txn1.zxid[1] < txn2.zxid[1]

GlobalPrimaryOrder == \A i \in Server: Len(confirmedHistory[i]) >= 2
                         => \A idx1, idx2 \in 1..Len(confirmedHistory[i]):
                                \/ ~EpochPrecedeInTxn(confirmedHistory[i][idx1], confirmedHistory[i][idx2])
                                \/ /\ EpochPrecedeInTxn(confirmedHistory[i][idx1], confirmedHistory[i][idx2])
                                   /\ idx1 < idx2

=============================================================================
