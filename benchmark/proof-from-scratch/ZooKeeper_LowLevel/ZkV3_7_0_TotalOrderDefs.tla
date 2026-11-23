------------------------ MODULE ZkV3_7_0_TotalOrderDefs ------------------------

EXTENDS ZkV3_7_0Model

TxnEqual(txn1, txn2) == /\ ZxidEqual(txn1.zxid, txn2.zxid)
                        /\ txn1.value = txn2.value

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

=============================================================================
