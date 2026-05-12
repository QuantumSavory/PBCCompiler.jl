    """
    This file contains pair transformation functions that operate on adjacent pair of CircuitOps
    """
##
using Moshi.Match: @match
using QuantumClifford: comm, embed, ⊗
"""
    _affectedpaulis(op::CircuitOp.Type) -> Vector{P}

Return the list of Pauli operators affected by a circuit operation.

# Examples
```jldoctest
julia> op = PBCCompiler.Pauli(P"XY", [1, 2]);

julia> PBCCompiler._affectedpaulis(op)  # returns [1, 2]
+ XY
```
```jldoctest
julia> op = PBCCompiler.PauliConditional(P"X", [1], P"Z", [3]);

julia> PBCCompiler._affectedpaulis(op)  # returns [1, 3]`
2-element Vector{PauliOperator{Array{UInt8, 0}, Vector{UInt64}}}:
 + X
 + Z
```
"""
function _affectedpaulis(op::CircuitOp.Type)
    pauli = @match op begin
        CircuitOp.Pauli(pauli, qubits) => pauli
        CircuitOp.Measurement(pauli, bit, qubits) => pauli
        CircuitOp.ExpHalfPiPauli(pauli, qubits) => pauli
        CircuitOp.ExpQuatPiPauli(pauli, qubits) => pauli
        CircuitOp.ExpEighPiPauli(pauli, qubits) => pauli
        CircuitOp.PauliConditional(cp, cq, tp, tq) => vcat(cp, tp)
        CircuitOp.BitConditional(inner_op, bit) => _affectedpaulis(inner_op)
    end
    return pauli
end

"""
    _complete_paulis(op1::CircuitOp.Type, op2::CircuitOp.Type) -> (PauliOperator, PauliOperator)

This helper function ensures that both operators are represented over the
    union of their affected qubits. It reorders strings to a canonical qubit
    ordering and pads missing sites with Identity operators ('_') to ensure
    equal string length.

# Examples
```jldoctest
julia> op1 = PBCCompiler.ExpQuatPiPauli(P"XY", [1, 3]);

julia> op2 = PBCCompiler.ExpQuatPiPauli(P"ZXY",[3, 1, 2]);

julia> PBCCompiler._complete_paulis(op1,op2)
(+ X_Y, + XYZ)
```
```jldoctest
julia> op1 = PBCCompiler.ExpQuatPiPauli(P"XY", [1, 3]);

julia> op2 = PBCCompiler.ExpHalfPiPauli(P"Z", [5]);

julia> PBCCompiler._complete_paulis(op1,op2)
(+ X_Y__, + ____Z)
```
"""
function _complete_paulis(op1::CircuitOp.Type, op2::CircuitOp.Type)
    pu1=_affectedpaulis(op1)
    pu2=_affectedpaulis(op2)
    @debug("Affected Paulis of op1: ", pu1)
    @debug("Affected Paulis of op2: ", pu2)
    qu1=_affectedqubits(op1)
    qu2=_affectedqubits(op2)
    @debug("Affected qubits of op1: ", qu1)
    @debug("Affected qubits of op2: ", qu2)
    AffectedQubbits=sort(union(qu1,qu2))
    @debug("Affected qubits of both ops: ", AffectedQubbits)
    Paulilen=maximum(AffectedQubbits)
    @debug("Length of the affected Pauli string: ", Paulilen)
    Pauli1=embed(Paulilen, op1.qubits, pu1)
    Pauli2=embed(Paulilen, op2.qubits, pu2)
    @debug("New Pauli string of op1: ", Pauli1)
    @debug("New Pauli string of op2: ", Pauli2)
    return (Pauli1, Pauli2)
end

"""
    check_commutation(op1::CircuitOp.Type, op2::CircuitOp.Type) -> Int

Return 0x00 if the two operations commute, and return 0x01 if they anticommute.
    For classical controlled gates, the function will print a message indicating that the input is invalid and that the gate present needs to be determined first.
    For Pauli Conditional gates, the function will check the commutation of the input operation with both the control and target Paulis of the conditional gate,
    and return a tuple indicating the commutation results.
    This function can handle all types of circuit operations defined in CircuitOp.

# Examples
```jldoctest
julia> op1 = PBCCompiler.ExpQuatPiPauli(P"XY", [1, 3]);

julia> op2 = PBCCompiler.ExpQuatPiPauli(P"ZXY",[3, 1, 2]);

julia> PBCCompiler.check_commutation(op1, op2)
0x01
```
```jldoctest
julia> op1 = PBCCompiler.ExpQuatPiPauli(P"XY", [1, 3]);

julia> CNOT = PBCCompiler.PauliConditional(P"Z", [1], P"X", [2]);

julia> PBCCompiler.check_commutation(op1, CNOT)
(0x01, 0x00)
```
"""
function check_commutation(op1::CircuitOp.Type, op2::CircuitOp.Type)

    @match (op1, op2) begin
        #scenario 1: One of them is classical controlled gate
        (op,CircuitOp.BitConditional(inner_op, bit)) || (CircuitOp.BitConditional(inner_op, bit), op) => begin
            println("Invalid input: Need to determine gate present first")
        end
        #scenario 2: One of them is Pauli Conditional gate
        (op, CircuitOp.PauliConditional(cp, cq, tp, tq)) || (CircuitOp.PauliConditional(cp, cq, tp, tq), op) => begin
            @debug("One of the operations is a Pauli conditional gate. ")
            cop=CircuitOp.ExpQuatPiPauli(cp, cq)
            top=CircuitOp.ExpQuatPiPauli(tp, tq)
            comm_cop=check_commutation(op, cop)
            comm_top=check_commutation(op, top)
            if comm_cop == 0 && comm_top == 0
                @debug("The operation commutes with both the control and target Paulis of the conditional gate.")
            elseif comm_cop != 0 && comm_top != 0
                @debug("The operation anticommutes with both the control and target Paulis of the conditional gate.")
            else
                @debug("The operation commutes with one of the control and target Paulis of the conditional gate, and anticommutes with the other.")
            end
            return (comm_cop, comm_top)
        end
        #scenario 3: Both are Pauli Product Rotations
        _ => begin
            (Pauli1,Pauli2)=_complete_paulis(op1, op2)
            commutativity=comm(Pauli1,Pauli2)
            if commutativity == 0
                @debug("The two operations commute.")
            else
                @debug("The two operations anticommute.")
            end
            return commutativity
        end


    end
end

"""
    conjugate(op1::CircuitOp.Type, op2::CircuitOp.Type) -> (conjugated_op2::CircuitOp.Type, op1::CircuitOp.Type)

    Move op2 pass op1 and update op2 by conjugating its pauli string by op1's pauli string.
    Will return nothing if any argument is BitConditional operations or trying to move a controlled gate pass a PPR.

# Examples
```jldoctest
julia> op1 = PBCCompiler.ExpQuatPiPauli(P"XY", [1, 3]);

julia> op2 = PBCCompiler.ExpQuatPiPauli(P"ZXY",[3, 1, 2]);

julia> PBCCompiler.conjugate(op1, op2)
(CircuitOp.ExpQuatPiPauli(pauli=- _YX, qubits=[1, 2, 3]), CircuitOp.ExpQuatPiPauli(pauli=+ XY, qubits=[1, 3]))
```
```jldoctest
julia> op1 = PBCCompiler.ExpQuatPiPauli(P"XY", [1, 3]);

julia> CNOT = PBCCompiler.PauliConditional(P"Z", [1], P"X", [2]);

julia> PBCCompiler.conjugate(CNOT, op1)
(CircuitOp.ExpQuatPiPauli(pauli=+ XXY, qubits=[1, 2, 3]), CircuitOp.PauliConditional(control_pauli=+ Z, control_qubits=[1], target_pauli=+ X, target_qubits=[2]))
```
"""
function conjugate(op1::CircuitOp.Type, op2::CircuitOp.Type) #first input is the one we conjugate by, second input is the one we want to conjugate
    conjugated_op=@match (op1, op2) begin
     #scenario 1: one is a BitControlled gate
        (op,CircuitOp.BitConditional(inner_op, bit)) || (CircuitOp.BitConditional(inner_op, bit), op) => begin
            return nothing
        end
    #scenario 2: Conjugated by a PauliControlled gate
        (CircuitOp.PauliConditional(cp, cq, tp, tq), op) => begin
            @debug("One of the operations is a Pauli conditional gate.")
            op_1=CircuitOp.ExpQuatPiPauli(-cp, cq)
            @debug("First conjugation with the control Pauli of the conditional gate.")
            op_2=CircuitOp.ExpQuatPiPauli(-tp, tq)
            @debug("Second conjugation with the target Pauli of the conditional gate.")
            op_3=CircuitOp.ExpQuatPiPauli(cp⊗tp, sort(union(cq, tq)))
            @debug("First conjugation with the control Pauli of the conditional gate.")
            conju_step1=conjugate(op_1, op2)[1]
            @debug("Second conjugation with the target Pauli of the conditional gate.")
            conju_step2=conjugate(op_2, conju_step1)[1]
            @debug("Third conjugation with the combined control and target Paulis of the conditional gate.")
            conju_final=conjugate(op_3, conju_step2)[1]
            conju_final
        end
        (op, CircuitOp.PauliConditional(cp, cq, tp, tq)) => nothing
    #scenario 3: Conjugated by a HalfPi Pauli
        (CircuitOp.ExpHalfPiPauli(p1,q1),op) => begin
        @debug("One of the operations is a HalfPi Pauli gate.")
            if check_commutation(op1,op2) == 0
                new_p=_complete_paulis(op1, op2)[2]
                new_qm=maximum(sort(union(q1, _affectedqubits(op2))))
                new_q=[x for x in 1:new_qm]
                @debug("The two operations commute, no change after conjugation.")
                @debug("The Pauli string of the conjugated operation is: ", new_p)
                @debug("The qubits affected by the conjugated operation are: ", new_q)
            else
                (pauli1,pauli2)=_complete_paulis(op1, op2)
                new_p=-pauli2
                new_qm=maximum(sort(union(_affectedqubits(op1), _affectedqubits(op2))))
                new_q=[x for x in 1:new_qm]
                @debug("The two operations anticommute, the Pauli string of the conjugated operation will be changed after conjugation.")
                @debug("The Pauli string of the conjugated operation is: ", new_p)
                @debug("The qubits affected by the conjugated operation are: ", new_q)
            end
            typeofp=variant_name(op2)
            if typeofp == :Measurement
                constructor=getproperty(CircuitOp, typeofp)
                new_op=constructor(new_p, op2.bit, new_q)
            else
            constructor=getproperty(CircuitOp, typeofp)
            new_op=constructor(new_p, new_q)
            end
            new_op
        end
    #scenario 4: PPM Conjugated by a ExpQuatPi Pauli
        (CircuitOp.ExpQuatPiPauli(p1,q1), CircuitOp.Measurement(p2,b,q2)) => begin
            if check_commutation(op1,op2) == 0
                new_p=_complete_paulis(op1, op2)[2]
                new_qm=maximum(sort(union(q1, q2)))
                new_q=[x for x in 1:new_qm]
                @debug("The two operations commute, no change after conjugation.")
                @debug("The Pauli string of the conjugated operation is: ", new_p)
                @debug("The qubits affected by the conjugated operation are: ", new_q)
            else
                (pauli1,pauli2)=_complete_paulis(op1, op2)
                new_p=1im*pauli1*pauli2
                new_qm=maximum(sort(union(q1, q2)))
                new_q=[x for x in 1:new_qm]
                @debug("The two operations anticommute, the Pauli string of the conjugated operation will be changed after conjugation.")
                @debug("The Pauli string of the conjugated operation is: ", new_p)
                @debug("The qubits affected by the conjugated operation are: ", new_q)
            end
            Measurement(new_p,b,new_q)
        end
    #scenario 5: PPR Conjugated by a ExpQuatPi Pauli
        (CircuitOp.ExpQuatPiPauli(p1,q1), op) => begin
            if check_commutation(op1,op2) == 0
                new_p=_complete_paulis(op1, op2)[2]
                new_qm=maximum(sort(union(q1, _affectedqubits(op2))))
                new_q=[x for x in 1:new_qm]
                @debug("The two operations commute, no change after conjugation.")
                @debug("The Pauli string of the conjugated operation is: ", new_p)
                @debug("The qubits affected by the conjugated operation are: ", new_q)
            else
                (pauli1,pauli2)=_complete_paulis(op1, op2)
                new_p=1im*pauli1*pauli2
                new_qm=maximum(sort(union(_affectedqubits(op1), _affectedqubits(op2))))
                new_q=[x for x in 1:new_qm]
                @debug("The two operations anticommute, the Pauli string of the conjugated operation will be changed after conjugation.")
                @debug("The Pauli string of the conjugated operation is: ", new_p)
                @debug("The qubits affected by the conjugated operation are: ", new_q)
            end
            typeofp=variant_name(op2)
            constructor=getproperty(CircuitOp, typeofp)
            new_op=constructor(new_p, new_q)
            new_op
        end
    #scenario 6: Conjugated by pi/8 PPR
        (CircuitOp.ExpEighPiPauli(), op) => nothing
    #scenario 7: Conjugated by measurement
        (CircuitOp.Measurement(), op) => nothing
        _=> begin
            throw(ArgumentError("Invalid input"))
        end

    end
    if conjugated_op === nothing
        return nothing
    else
        return (conjugated_op,op1)
    end
end

"""
Helper functions to cancel out adjacent PPR pair
"""
function _merge_rotations(op1::CircuitOp.Type, op2::CircuitOp.Type)
    @match (op1,op2) begin
        (CircuitOp.ExpEighPiPauli(),CircuitOp.ExpEighPiPauli()) => begin
            (p1,p2)=_complete_paulis(op1,op2)
            qm=maximum(sort(union(_affectedqubits(op1), _affectedqubits(op2))))
            q=[x for x in 1:qm]
            if p1.xz == p2.xz
                if xor(p1.phase[1], p2.phase[1]) == 0x02
                    return CircuitOp.ExpHalfPiPauli(p1*p2,q)
                elseif op1.pauli.phase == op2.pauli.phase
                    return CircuitOp.ExpQuatPiPauli(p1,q)
                else
                    return nothing
                end
            else return nothing
            end
        end
        (CircuitOp.ExpQuatPiPauli(),CircuitOp.ExpQuatPiPauli()) => begin
            (p1,p2)=_complete_paulis(op1,op2)
            qm=maximum(sort(union(_affectedqubits(op1), _affectedqubits(op2))))
            q=[x for x in 1:qm]
            if p1.xz == p2.xz
                if xor(p1.phase[1], p2.phase[1]) == 0x02
                    return CircuitOp.ExpHalfPiPauli(p1*p2,q)
                elseif op1.pauli.phase == op2.pauli.phase
                    return CircuitOp.ExpHalfPiPauli(p1,q)
                else
                    return nothing
                end
            else return nothing
            end
        end
        (CircuitOp.ExpHalfPiPauli(),CircuitOp.ExpHalfPiPauli()) => begin
            (p1,p2)=_complete_paulis(op1,op2)
            qm=maximum(sort(union(_affectedqubits(op1), _affectedqubits(op2))))
            q=[x for x in 1:qm]
            if p1.xz == p2.xz
                return CircuitOp.ExpHalfPiPauli(p1*p2,q)
            else return nothing
            end
        end
        _ => nothing
    end
end
