---- MODULE ConfirmedHistoryReplay ----
EXTENDS ZkV3_7_0
CONSTANTS B, C, D, E, T, Scenario
VARIABLE pc
RequestValues == {0}

\* Five voters, ordered B > C > D > E > T by the original IdTable.
\* B uses the same election and discovery schedule before and after its crash.
ElectB(k) ==
    CASE k = 1 -> FLEHandleNotmsg(B)
      [] k = 2 -> FLEReceiveNotmsg(C, B)
      [] k = 3 -> FLEHandleNotmsg(C)
      [] k = 4 -> FLEReceiveNotmsg(D, B)
      [] k = 5 -> FLEHandleNotmsg(D)
      [] k = 6 -> FLEReceiveNotmsg(D, C)
      [] k = 7 -> FLEHandleNotmsg(D)
      [] k = 8 -> FLEReceiveNotmsg(B, C)
      [] k = 9 -> FLEHandleNotmsg(B)
      [] k = 10 -> FLEReceiveNotmsg(B, D)
      [] k = 11 -> FLEHandleNotmsg(B)
      [] k = 12 -> FLEWaitNewNotmsg(B)
      [] k = 13 -> FLEReceiveNotmsg(C, D)
      [] k = 14 -> FLEHandleNotmsg(C)
      [] k = 15 -> FLEWaitNewNotmsg(C)
      [] k = 16 -> FLEWaitNewNotmsg(D)
      [] k = 17 -> ConnectAndFollowerSendFOLLOWERINFO(B, C)
      [] k = 18 -> ConnectAndFollowerSendFOLLOWERINFO(B, D)
      [] k = 19 -> LeaderProcessFOLLOWERINFO(B, C)
      [] k = 20 -> LeaderProcessFOLLOWERINFO(B, D)
      [] k = 21 -> FollowerProcessLEADERINFO(C, B)
      [] k = 22 -> FollowerProcessLEADERINFO(D, B)
      [] k = 23 -> LeaderProcessACKEPOCH(B, C)
      [] k = 24 -> LeaderProcessACKEPOCH(B, D)
      [] OTHER -> FALSE

FirstEpoch(k) ==
    CASE k = 0 -> FLENotmsgTimeout(B)
      [] k \in 1..24 -> ElectB(k)
      [] k = 25 -> LeaderSyncFollower(B, C)
      [] k = 26 -> LeaderSyncFollower(B, D)
      [] k = 27 -> FollowerProcessSyncMessage(C, B)
      [] k = 28 -> FollowerProcessNEWLEADER(C, B)
      [] k = 29 -> FollowerProcessSyncMessage(D, B)
      [] k = 30 -> FollowerProcessNEWLEADER(D, B)
      [] k = 31 -> LeaderProcessACKLD(B, C)
      [] k = 32 -> LeaderProcessACKLD(B, D)
      [] k = 33 -> FollowerProcessUPTODATE(C, B)
      [] k = 34 -> FollowerProcessUPTODATE(D, B)
      [] k = 35 -> LeaderProcessRequest(B)
      [] OTHER -> FALSE

\* B reopens its uncommitted (1,1). T installs B's SNAP and ACKs NEWLEADER.
SecondEpoch(k) ==
    CASE k = 36 -> NodeCrash(B)
      [] k = 37 -> NodeStart(B)
      [] k \in 38..61 -> ElectB(k - 37)
      [] k = 62 -> FLEReceiveNotmsg(T, B)
      [] k = 63 -> FLEHandleNotmsg(T)
      [] k = 64 -> FLEReceiveNotmsg(T, B)
      [] k = 65 -> FLEHandleNotmsg(T)
      [] k = 66 -> FLEReceiveNotmsg(T, C)
      [] k = 67 -> FLEHandleNotmsg(T)
      [] k = 68 -> FLEReceiveNotmsg(T, C)
      [] k = 69 -> FLEHandleNotmsg(T)
      [] k = 70 -> FLEWaitNewNotmsg(T)
      [] k = 71 -> ConnectAndFollowerSendFOLLOWERINFO(B, T)
      [] k = 72 -> LeaderProcessFOLLOWERINFO(B, T)
      [] k = 73 -> FollowerProcessLEADERINFO(T, B)
      [] k = 74 -> LeaderProcessACKEPOCH(B, T)
      [] k = 75 -> LeaderSyncFollower(B, T)
      [] k = 76 -> FollowerProcessSyncMessage(T, B)
      [] k = 77 -> FollowerProcessNEWLEADER(T, B)
      [] OTHER -> FALSE

\* B loses the epoch before activation. C, D and E can agree on (3,1).
\* T subsequently follows C with its previous disk image.
Interrupted(k) ==
    CASE k = 78 -> NodeCrash(B)
      [] k = 79 -> FLEHandleNotmsg(C)
      [] k = 80 -> FLEReceiveNotmsg(D, C)
      [] k = 81 -> FLEHandleNotmsg(D)
      [] k = 82 -> FLEReceiveNotmsg(E, C)
      [] k = 83 -> FLEHandleNotmsg(E)
      [] k = 84 -> FLEReceiveNotmsg(E, C)
      [] k = 85 -> FLEHandleNotmsg(E)
      [] k = 86 -> FLEReceiveNotmsg(E, C)
      [] k = 87 -> FLEHandleNotmsg(E)
      [] k = 88 -> FLEReceiveNotmsg(E, D)
      [] k = 89 -> FLEHandleNotmsg(E)
      [] k = 90 -> FLEReceiveNotmsg(E, D)
      [] k = 91 -> FLEHandleNotmsg(E)
      [] k = 92 -> FLEReceiveNotmsg(E, D)
      [] k = 93 -> FLEHandleNotmsg(E)
      [] k = 94 -> FLEWaitNewNotmsg(E)
      [] k = 95 -> FLEReceiveNotmsg(C, D)
      [] k = 96 -> FLEHandleNotmsg(C)
      [] k = 97 -> FLEReceiveNotmsg(C, E)
      [] k = 98 -> FLEHandleNotmsg(C)
      [] k = 99 -> FLEReceiveNotmsg(C, E)
      [] k = 100 -> FLEHandleNotmsg(C)
      [] k = 101 -> FLEReceiveNotmsg(C, E)
      [] k = 102 -> FLEHandleNotmsg(C)
      [] k = 103 -> FLEWaitNewNotmsg(C)
      [] k = 104 -> FLEReceiveNotmsg(D, E)
      [] k = 105 -> FLEHandleNotmsg(D)
      [] k = 106 -> FLEReceiveNotmsg(D, E)
      [] k = 107 -> FLEHandleNotmsg(D)
      [] k = 108 -> FLEReceiveNotmsg(D, E)
      [] k = 109 -> FLEHandleNotmsg(D)
      [] k = 110 -> FLEWaitNewNotmsg(D)
      [] k = 111 -> ConnectAndFollowerSendFOLLOWERINFO(C, D)
      [] k = 112 -> ConnectAndFollowerSendFOLLOWERINFO(C, E)
      [] k = 113 -> LeaderProcessFOLLOWERINFO(C, D)
      [] k = 114 -> LeaderProcessFOLLOWERINFO(C, E)
      [] k = 115 -> FollowerProcessLEADERINFO(D, C)
      [] k = 116 -> FollowerProcessLEADERINFO(E, C)
      [] k = 117 -> LeaderProcessACKEPOCH(C, D)
      [] k = 118 -> LeaderProcessACKEPOCH(C, E)
      [] k = 119 -> LeaderSyncFollower(C, D)
      [] k = 120 -> LeaderSyncFollower(C, E)
      [] k = 121 -> FollowerProcessSyncMessage(D, C)
      [] k = 122 -> FollowerProcessNEWLEADER(D, C)
      [] k = 123 -> FollowerProcessSyncMessage(E, C)
      [] k = 124 -> FollowerProcessNEWLEADER(E, C)
      [] k = 125 -> LeaderProcessACKLD(C, D)
      [] k = 126 -> LeaderProcessACKLD(C, E)
      [] k = 127 -> FollowerProcessUPTODATE(D, C)
      [] k = 128 -> FollowerProcessUPTODATE(E, C)
      [] k = 129 -> LeaderProcessRequest(C)
      [] k = 130 -> FollowerProcessPROPOSAL(D, C)
      [] k = 131 -> FollowerProcessPROPOSAL(E, C)
      [] k = 132 -> LeaderProcessACK(C, D)
      [] k = 133 -> LeaderProcessACK(C, E)
      [] k = 134 -> FollowerProcessCOMMIT(D, C)
      [] k = 135 -> FLEHandleNotmsg(T)
      [] k = 136 -> FLEReceiveNotmsg(C, T)
      [] k = 137 -> FLEReceiveNotmsg(T, C)
      [] k = 138 -> FLEHandleNotmsg(T)
      [] k = 139 -> FLEReceiveNotmsg(T, C)
      [] k = 140 -> FLEHandleNotmsg(T)
      [] OTHER -> FALSE

\* Alternatively B collects a NEWLEADER quorum, then T receives UPTODATE.
Activated(k) ==
    CASE k = 78 -> LeaderSyncFollower(B, C)
      [] k = 79 -> FollowerProcessSyncMessage(C, B)
      [] k = 80 -> FollowerProcessNEWLEADER(C, B)
      [] k = 81 -> LeaderProcessACKLD(B, T)
      [] k = 82 -> LeaderProcessACKLD(B, C)
      [] k = 83 -> FollowerProcessUPTODATE(T, B)
      [] k = 84 -> NodeCrash(B)
      [] k = 85 -> NodeCrash(T)
      [] k = 86 -> NodeStart(T)
      [] OTHER -> FALSE

\* T joins an active B with one outstanding proposal. B can commit it
\* either before or after T receives UPTODATE on their FIFO connection.
JoinActive(k) ==
    CASE k = 36 -> FLEReceiveNotmsg(T, B)
      [] k = 37 -> FLEHandleNotmsg(T)
      [] k = 38 -> FLEReceiveNotmsg(T, C)
      [] k = 39 -> FLEHandleNotmsg(T)
      [] k = 40 -> FLEWaitNewNotmsg(T)
      [] k = 41 -> ConnectAndFollowerSendFOLLOWERINFO(B, T)
      [] k = 42 -> LeaderProcessFOLLOWERINFO(B, T)
      [] k = 43 -> FollowerProcessLEADERINFO(T, B)
      [] k = 44 -> LeaderProcessACKEPOCH(B, T)
      [] k = 45 -> LeaderSyncFollower(B, T)
      [] k = 46 -> FollowerProcessSyncMessage(T, B)
      [] k = 47 -> FollowerProcessPROPOSALInSync(T, B)
      [] k = 48 -> FollowerProcessNEWLEADER(T, B)
      [] OTHER -> FALSE

CommitProposal(k) ==
    CASE k = 0 -> FollowerProcessPROPOSAL(C, B)
      [] k = 1 -> FollowerProcessPROPOSAL(D, B)
      [] k = 2 -> LeaderProcessACK(B, C)
      [] k = 3 -> LeaderProcessACK(B, D)
      [] OTHER -> FALSE

LateCommit(k) ==
    CASE k = 49 -> LeaderProcessACKLD(B, T)
      [] k = 50 -> FollowerProcessUPTODATE(T, B)
      [] k \in 51..54 -> CommitProposal(k - 51)
      [] k = 55 -> FollowerProcessCOMMIT(T, B)
      [] OTHER -> FALSE

EarlyCommit(k) ==
    CASE k \in 49..52 -> CommitProposal(k - 49)
      [] k = 53 -> FollowerProcessCOMMITInSync(T, B)
      [] k = 54 -> LeaderProcessACKLD(B, T)
      [] k = 55 -> FollowerProcessUPTODATE(T, B)
      [] OTHER -> FALSE

JoinScenario == Scenario \in {"early-commit", "late-commit"}
LastStep == CASE Scenario = "interrupted" -> 141
              [] Scenario = "activated" -> 87
              [] JoinScenario -> 56

Step ==
    IF pc < 36 THEN FirstEpoch(pc)
    ELSE IF JoinScenario THEN
        IF pc < 49 THEN JoinActive(pc)
        ELSE IF Scenario = "early-commit" THEN EarlyCommit(pc) ELSE LateCommit(pc)
    ELSE IF pc < 78 THEN SecondEpoch(pc)
    ELSE IF Scenario = "interrupted" THEN Interrupted(pc) ELSE Activated(pc)

TraceInit == Init /\ pc = 0
TraceNext == Step /\ pc' = pc + 1
TraceVars == <<vars, pc>>
TraceSpec == TraceInit /\ [][TraceNext]_TraceVars /\ WF_TraceVars(TraceNext)
Completed == <>(pc = LastStep)

\* Check observations independently of the protocol guards.
ExtendsConfirmed ==
    \A s \in Server : /\ Len(confirmedHistory'[s]) >= Len(confirmedHistory[s])
                       /\ SubSeq(confirmedHistory'[s], 1, Len(confirmedHistory[s])) = confirmedHistory[s]
KeepsConfirmed == [][ExtendsConfirmed]_vars
ServingMatches ==
    \A s \in Server : zabState[s] = BROADCAST =>
        /\ lastCommitted[s].index \in 0..Len(history[s])
        /\ Len(confirmedHistory[s]) = lastCommitted[s].index
        /\ \A k \in DOMAIN confirmedHistory[s] : TxnEqual(confirmedHistory[s][k], history[s][k])

BootstrapOnly(s) == confirmedHistory[s] = <<[zxid |-> BootstrapZxid, value |-> 0]>>
ConfirmedSecond(s, zxid) == /\ Len(confirmedHistory[s]) = 2
                             /\ confirmedHistory[s][2] = [zxid |-> zxid, value |-> 0]

Checkpoints ==
    /\ (~JoinScenario /\ pc = 78 =>
            /\ connectInfo[T].nlRcv /\ lastSnapshot[T].index = 2
            /\ history[T][2].zxid = <<1,1>> /\ BootstrapOnly(T))
    /\ (Scenario = "interrupted" /\ pc >= 78 => BootstrapOnly(T))
    /\ (Scenario = "interrupted" /\ pc = 141 =>
            /\ state[T] = FOLLOWING /\ state[D] = FOLLOWING
            /\ ConfirmedSecond(C, <<3,1>>) /\ ConfirmedSecond(D, <<3,1>>))
    /\ (Scenario = "activated" /\ pc = 82 => BootstrapOnly(B) /\ BootstrapOnly(T))
    /\ (Scenario = "activated" /\ pc = 83 => ConfirmedSecond(B, <<1,1>>) /\ BootstrapOnly(T))
    /\ (Scenario = "activated" /\ pc >= 84 => ConfirmedSecond(T, <<1,1>>))
    /\ (JoinScenario /\ pc = 49 => Len(history[T]) = 2 /\ BootstrapOnly(T))
    /\ (Scenario = "late-commit" /\ pc = 51 => zabState[T] = BROADCAST /\ BootstrapOnly(T))
    /\ (Scenario = "early-commit" /\ pc = 55 => BootstrapOnly(T))
    /\ (JoinScenario /\ pc = 56 => ConfirmedSecond(B, <<1,1>>) /\ ConfirmedSecond(T, <<1,1>>))
====
