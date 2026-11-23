------------------------ MODULE ZkV3_7_0Defs ------------------------

EXTENDS ZkV3_7_0Model

TxnEqual(txn1, txn2) == /\ ZxidEqual(txn1.zxid, txn2.zxid)
                        /\ txn1.value = txn2.value

EpochPrecedeInTxn(txn1, txn2) == txn1.zxid[1] < txn2.zxid[1]

Leadership1 == \A i, j \in Server:
                   /\ IsLeader(i) /\ zabState[i] \in {SYNCHRONIZATION, BROADCAST}
                   /\ IsLeader(j) /\ zabState[j] \in {SYNCHRONIZATION, BROADCAST}
                   /\ acceptedEpoch[i] = acceptedEpoch[j]
                  => i = j

Leadership2 == \A epoch \in 1..MAXEPOCH: Cardinality(epochLeader[epoch]) <= 1

PrefixConsistency == \A i, j \in Server:
                        LET smaller == Minimum({Len(confirmedHistory[i]), Len(confirmedHistory[j])})
                        IN \/ smaller = 0
                           \/ /\ smaller > 0
                              /\ \A index \in 1..smaller:
                                   TxnEqual(confirmedHistory[i][index], confirmedHistory[j][index])

Integrity == \A i \in Server:
                /\ IsFollower(i)
                /\ Len(confirmedHistory[i]) > 0
                => \A idx \in 1..Len(confirmedHistory[i]): \E proposal \in proposalMsgsLog:
                    LET txn_proposal == [ zxid  |-> proposal.zxid,
                                          value |-> proposal.data ]
                    IN  TxnEqual(confirmedHistory[i][idx], txn_proposal)

Agreement == \A i, j \in Server:
                /\ IsFollower(i) /\ Len(confirmedHistory[i]) > 0
                /\ IsFollower(j) /\ Len(confirmedHistory[j]) > 0
                =>
                \A idx1 \in 1..Len(confirmedHistory[i]), idx2 \in 1..Len(confirmedHistory[j]) :
                    \/ \E idx_j \in 1..Len(confirmedHistory[j]):
                        TxnEqual(confirmedHistory[j][idx_j], confirmedHistory[i][idx1])
                    \/ \E idx_i \in 1..Len(confirmedHistory[i]):
                        TxnEqual(confirmedHistory[i][idx_i], confirmedHistory[j][idx2])

TotalOrder == \A i, j \in Server: 
                LET committed1 == Len(confirmedHistory[i])
                    committed2 == Len(confirmedHistory[j])
                IN committed1 >= 2 /\ committed2 >= 2
                    => \A idx_i1 \in 1..(committed1 - 1) : \A idx_i2 \in (idx_i1 + 1)..committed1 :
                    LET logOk == \E idx \in 1..committed2 :
                                     TxnEqual(confirmedHistory[i][idx_i2], confirmedHistory[j][idx])
                    IN \/ ~logOk 
                       \/ /\ logOk 
                          /\ \E idx_j2 \in 1..committed2 : 
                                /\ TxnEqual(confirmedHistory[i][idx_i2], confirmedHistory[j][idx_j2])
                                /\ \E idx_j1 \in 1..(idx_j2 - 1):
                                       TxnEqual(confirmedHistory[i][idx_i1], confirmedHistory[j][idx_j1])

LocalPrimaryOrder == LET p_set(i, e) == {p \in proposalMsgsLog: /\ p.source = i 
                                                                /\ p.epoch  = e }
                         txn_set(i, e) == { [ zxid  |-> p.zxid, 
                                              value |-> p.data ] : p \in p_set(i, e) }
                     IN \A i \in Server: \A e \in 1..currentEpoch[i]:
                         \/ Cardinality(txn_set(i, e)) < 2
                         \/ /\ Cardinality(txn_set(i, e)) >= 2
                            /\ \A txn1, txn2 \in txn_set(i, e):
                             \/ TxnEqual(txn1, txn2)
                             \/ /\ ~TxnEqual(txn1, txn2)
                                /\ LET TxnPre  == IF ZxidCompare(txn1.zxid, txn2.zxid) THEN txn2 ELSE txn1
                                       TxnNext == IF ZxidCompare(txn1.zxid, txn2.zxid) THEN txn1 ELSE txn2
                                   IN \A j \in Server: (\E idx \in 1..Len(confirmedHistory[j]):
                                                            TxnEqual(confirmedHistory[j][idx], TxnNext))
                                        => \E idx2 \in 1..Len(confirmedHistory[j]):
                                            /\ TxnEqual(confirmedHistory[j][idx2], TxnNext)
                                            /\ idx2 > 1
                                            /\ \E idx1 \in 1..(idx2 - 1): 
                                                TxnEqual(confirmedHistory[j][idx1], TxnPre)

GlobalPrimaryOrder == \A i \in Server: Len(confirmedHistory[i]) >= 2
                         => \A idx1, idx2 \in 1..Len(confirmedHistory[i]):
                                \/ ~EpochPrecedeInTxn(confirmedHistory[i][idx1], confirmedHistory[i][idx2])
                                \/ /\ EpochPrecedeInTxn(confirmedHistory[i][idx1], confirmedHistory[i][idx2])
                                   /\ idx1 < idx2

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
