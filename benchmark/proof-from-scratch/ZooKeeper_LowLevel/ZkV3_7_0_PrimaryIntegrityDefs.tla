------------------------ MODULE ZkV3_7_0_PrimaryIntegrityDefs ------------------------

EXTENDS ZkV3_7_0Model

TxnEqual(txn1, txn2) == /\ ZxidEqual(txn1.zxid, txn2.zxid)
                        /\ txn1.value = txn2.value

PrimaryIntegrity == \A i, j \in Server: /\ IsLeader(i)   /\ IsMyLearner(i, j)
                                        /\ IsFollower(j) /\ IsMyLeader(j, i)
                                        /\ zabState[i] = BROADCAST
                                        /\ zabState[j] = BROADCAST
                                        /\ Len(confirmedHistory[j]) >= 1
                        => \A idx_j \in 1..Len(confirmedHistory[j]):
                                \/ confirmedHistory[j][idx_j].zxid[1] >= currentEpoch[i]
                                \/ /\ confirmedHistory[j][idx_j].zxid[1] < currentEpoch[i]
                                   /\ \E idx_i \in 1..Len(confirmedHistory[i]):
                                        TxnEqual(confirmedHistory[i][idx_i], confirmedHistory[j][idx_j])

=============================================================================
