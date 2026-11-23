------------------------ MODULE ZkV3_7_0_PrefixConsistencyDefs ------------------------

EXTENDS ZkV3_7_0Model

TxnEqual(txn1, txn2) == /\ ZxidEqual(txn1.zxid, txn2.zxid)
                        /\ txn1.value = txn2.value

PrefixConsistency == \A i, j \in Server:
                        LET smaller == Minimum({Len(confirmedHistory[i]), Len(confirmedHistory[j])})
                        IN \/ smaller = 0
                           \/ /\ smaller > 0
                              /\ \A index \in 1..smaller:
                                   TxnEqual(confirmedHistory[i][index], confirmedHistory[j][index])

=============================================================================
