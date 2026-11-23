------------------------ MODULE ZkV3_7_0_IntegrityDefs ------------------------

EXTENDS ZkV3_7_0Model

TxnEqual(txn1, txn2) == /\ ZxidEqual(txn1.zxid, txn2.zxid)
                        /\ txn1.value = txn2.value

Integrity == \A i \in Server:
                /\ IsFollower(i)
                /\ Len(confirmedHistory[i]) > 0
                => \A idx \in 1..Len(confirmedHistory[i]): \E proposal \in proposalMsgsLog:
                    LET txn_proposal == [ zxid  |-> proposal.zxid,
                                          value |-> proposal.data ]
                    IN  TxnEqual(confirmedHistory[i][idx], txn_proposal)

=============================================================================
