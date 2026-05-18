    """
    This file contains pair transformation functions that operate on adjacent pair of CircuitOps
    """
##
using Moshi.Match: @match
using QuantumClifford: comm, embed, ⊗
"""
    affectedpaulis(op::CircuitOp.Type) -> Vector{P}

Return the list of Pauli operators affected by a circuit operation.

# Examples
```jldoctest
julia> op = PBCCompiler.Pauli(P"XY", [1, 2]);

julia> PBCCompiler.affectedpaulis(op)  # returns [1, 2]
+ XY
```
```jldoctest
julia> op = PBCCompiler.PauliConditional(P"X", [1], P"Z", [3]);

julia> PBCCompiler.affectedpaulis(op)  # returns [1, 3]`
2-element Vector{PauliOperator{Array{UInt8, 0}, Vector{UInt64}}}:
 + X
 + Z
```
"""
function affectedpaulis(op::CircuitOp.Type)
    pauli = @match op begin
        CircuitOp.Pauli(pauli, qubits) => pauli
        CircuitOp.Measurement(pauli, bit, qubits) => pauli
        CircuitOp.ExpHalfPiPauli(pauli, qubits) => pauli
        CircuitOp.ExpQuatPiPauli(pauli, qubits) => pauli
        CircuitOp.ExpEighPiPauli(pauli, qubits) => pauli
        CircuitOp.PauliConditional(cp, cq, tp, tq) => vcat(cp, tp)
        CircuitOp.BitConditional(inner_op, bit) => affectedpaulis(inner_op)
    end
    return pauli
end

"""
    complete_paulis(op1::CircuitOp.Type, op2::CircuitOp.Type) -> (PauliOperator, PauliOperator)

This helper function ensures that both operators are represented over the
union of their affected qubits. It reorders strings to a canonical qubit
ordering and pads missing sites with Identity operators ('_') to ensure
equal string length.

# Examples
```jldoctest
julia> op1 = PBCCompiler.ExpQuatPiPauli(P"XY", [1, 3]);

julia> op2 = PBCCompiler.ExpQuatPiPauli(P"ZXY",[3, 1, 2]);

julia> PBCCompiler.complete_paulis(op1,op2)
(+ X_Y, + XYZ)
```
```jldoctest
julia> op1 = PBCCompiler.ExpQuatPiPauli(P"XY", [1, 3]);

julia> op2 = PBCCompiler.ExpHalfPiPauli(P"Z", [5]);

julia> PBCCompiler.complete_paulis(op1,op2)
(+ X_Y__, + ____Z)
```
"""
function complete_paulis(op1::CircuitOp.Type, op2::CircuitOp.Type)
    pu1=affectedpaulis(op1)
    pu2=affectedpaulis(op2)
    qu1=affectedqubits(op1)
    qu2=affectedqubits(op2)
    AffectedQubbits=sort(union(qu1,qu2))
    Paulilen=maximum(AffectedQubbits)
    Pauli1=embed(Paulilen, op1.qubits, pu1)
    Pauli2=embed(Paulilen, op2.qubits, pu2)
    return (Pauli1, Pauli2)
end

"""
    check_commutation(op1::CircuitOp.Type, op2::CircuitOp.Type) -> Union{Int8, Nothing}

Return 0x00 if the two Pauli Product Rotations/Measurements commute, and return 0x01 if they anticommute.
For inputs contain PauliConditional or BitConditional, function returns nothing

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
```
"""
function check_commutation(op1::CircuitOp.Type, op2::CircuitOp.Type)
    @match (op1, op2) begin
        #scenario 1: One of them is Bit Conditional gate
        (op,CircuitOp.BitConditional(inner_op, bit)) || (CircuitOp.BitConditional(inner_op, bit), op) => begin
            return nothing
        end
        #scenario 2: One of them is Pauli Conditional gate
        (op,CircuitOp.PauliConditional()) || (CircuitOp.PauliConditional(), op) => begin
            return nothing
        end
        #scenario 3: Inputs are Pauli Product Rotations or Pauli Product Measurements
        _ => begin
            (Pauli1,Pauli2)=complete_paulis(op1, op2)
            commutativity=comm(Pauli1,Pauli2)
            return commutativity
        end
    end
end

"""
    conjugate_noncliff(op1::CircuitOp.Type, op2::CircuitOp.Type) -> Union{(conjugated_op2::CircuitOp.Type, op1::CircuitOp.Type), Nothing}

Move a non-Clifford CircuitOp op2 pass a Clifford CircuitOp op1 and update op2 by conjugating its pauli string by op1's pauli string.
Will throw error message if op2 is not a ExpEighPiPauli CircuitOp. Return nothing if op1 is not a ExpHalfPiPauli or a ExpQuatPiPauli.

# Examples
```jldoctest
julia> op1 = PBCCompiler.ExpQuatPiPauli(P"XY", [1, 3]);

julia> op2 = PBCCompiler.ExpEighPiPauli(P"ZXY",[3, 1, 2]);

julia> PBCCompiler.conjugate_noncliff(op1, op2)
(CircuitOp.ExpEighPiPauli(pauli=- _YX, qubits=[1, 2, 3]), CircuitOp.ExpQuatPiPauli(pauli=+ XY, qubits=[1, 3]))
```
```jldoctest
julia> op1 = PBCCompiler.ExpQuatPiPauli(P"XY", [1, 3]);

julia> M_Z = PBCCompiler.Measurement(P"Z", 1, [2]);

julia> PBCCompiler.conjugate_noncliff(op1, M_Z)
ERROR: ArgumentError: conjugate_noncliff got unexpected variant: Measurement
```
"""
function conjugate_noncliff(op1::CircuitOp.Type, op2::CircuitOp.Type)
    if !isa_variant(op2, CircuitOp.ExpEighPiPauli)
        throw(ArgumentError("conjugate_noncliff got unexpected variant: $(variant_name(op2))"))
    end
    conjugated_op=@match op1 begin
        CircuitOp.ExpHalfPiPauli() => begin
            (new_p, new_q) = conjugated_by_ExpHalfPiPauli(op1,op2)
            CircuitOp.ExpEighPiPauli(new_p, new_q)
        end
        CircuitOp.ExpQuatPiPauli() => begin
            (new_p, new_q) = conjugated_by_ExpQuatPiPauli(op1,op2)
            CircuitOp.ExpEighPiPauli(new_p, new_q)
        end
        _=> nothing
    end
    return conjugated_op===nothing ? nothing : (conjugated_op,op1)
end
##

"""
    conjugate_measurement(op1::CircuitOp.Type, op2::CircuitOp.Type) -> Union{(conjugated_op2::CircuitOp.Type, op1::CircuitOp.Type), Nothing}

Move a Measurement CircuitOp op2 pass a Clifford CircuitOp op1 and update op2 by conjugating its pauli string by op1's pauli string.
Will throw error message if op2 is not a Measurement CircuitOp. Return nothing if op1 is not a ExpHalfPiPauli or a ExpQuatPiPauli.

# Examples
```jldoctest
julia> op1 = PBCCompiler.ExpQuatPiPauli(P"XY", [1, 3]);

julia> M_Z=PBCCompiler.Measurement(P"Z", 1, [2]);

julia> PBCCompiler.conjugate_measurement(op1, M_Z)
(CircuitOp.Measurement(pauli=+ _Z_, bit=1, qubits=[1, 2, 3]), CircuitOp.ExpQuatPiPauli(pauli=+ XY, qubits=[1, 3]))
```
```jldoctest
julia> op1 = PBCCompiler.ExpQuatPiPauli(P"XY", [1, 3]);

julia> op2 = PBCCompiler.ExpEighPiPauli(P"ZXY",[3, 1, 2]);

julia> PBCCompiler.conjugate_measurement(op1, op2)
ERROR: ArgumentError: conjugate_measurement got unexpected variant: ExpEighPiPauli
```
"""
function conjugate_measurement(op1::CircuitOp.Type, op2::CircuitOp.Type)
    if !isa_variant(op2, CircuitOp.Measurement)
        throw(ArgumentError("conjugate_measurement got unexpected variant: $(variant_name(op2))"))
    else
        b=op2.bit
        conjugated_op=@match op1 begin
            CircuitOp.ExpHalfPiPauli() => begin
                (new_p, new_q) = conjugated_by_ExpHalfPiPauli(op1,op2)
                CircuitOp.Measurement(new_p, b, new_q)
            end
            CircuitOp.ExpQuatPiPauli() => begin
                (new_p, new_q) = conjugated_by_ExpQuatPiPauli(op1,op2)
                CircuitOp.Measurement(new_p, b, new_q)
            end
            _=> nothing
        end
    end
    return conjugated_op===nothing ? nothing : (conjugated_op,op1)
end
##
function conjugated_by_ExpHalfPiPauli(op1::CircuitOp.Type, op2::CircuitOp.Type)
    if check_commutation(op1,op2) == 0
        new_p=complete_paulis(op1, op2)[2]
        new_qm=maximum(sort(union(affectedqubits(op1), affectedqubits(op2))))
        new_q=[x for x in 1:new_qm]
    else
        (pauli1,pauli2)=complete_paulis(op1, op2)
        new_p=-pauli2
        new_qm=maximum(sort(union(affectedqubits(op1), affectedqubits(op2))))
        new_q=[x for x in 1:new_qm]
    end
    return (new_p,new_q)
end

function conjugated_by_ExpQuatPiPauli(op1::CircuitOp.Type, op2::CircuitOp.Type)
    if check_commutation(op1,op2) == 0
        new_p=complete_paulis(op1, op2)[2]
        new_qm=maximum(sort(union(affectedqubits(op1), affectedqubits(op2))))
        new_q=[x for x in 1:new_qm]
    else
        (pauli1,pauli2)=complete_paulis(op1, op2)
        new_p=1im*pauli1*pauli2
        new_qm=maximum(sort(union(affectedqubits(op1), affectedqubits(op2))))
        new_q=[x for x in 1:new_qm]
    end
    return (new_p,new_q)
end
##
"""
Helper functions to cancel out adjacent PPR pair
"""
function merge_rotations(op1::CircuitOp.Type, op2::CircuitOp.Type)
    @match (op1,op2) begin
        (ExpEighPiPauli(),ExpEighPiPauli()) => begin
            (p1,p2)=complete_paulis(op1,op2)
            qm=maximum(sort(union(affectedqubits(op1), affectedqubits(op2))))
            q=[x for x in 1:qm]
            if p1.xz == p2.xz
                if xor(p1.phase[1], p2.phase[1]) == 0x02
                    return ExpHalfPiPauli(p1*p2,q)
                elseif op1.pauli.phase == op2.pauli.phase
                    return ExpQuatPiPauli(p1,q)
                else
                    return nothing
                end
            else return nothing
            end
        end
        (ExpQuatPiPauli(),ExpQuatPiPauli()) => begin
            (p1,p2)=complete_paulis(op1,op2)
            qm=maximum(sort(union(affectedqubits(op1), affectedqubits(op2))))
            q=[x for x in 1:qm]
            if p1.xz == p2.xz
                if xor(p1.phase[1], p2.phase[1]) == 0x02
                    return ExpHalfPiPauli(p1*p2,q)
                elseif op1.pauli.phase == op2.pauli.phase
                    return ExpHalfPiPauli(p1,q)
                else
                    return nothing
                end
            else return nothing
            end
        end
        (ExpHalfPiPauli(),ExpHalfPiPauli()) => begin
            (p1,p2)=complete_paulis(op1,op2)
            qm=maximum(sort(union(affectedqubits(op1), affectedqubits(op2))))
            q=[x for x in 1:qm]
            if p1.xz == p2.xz
                return ExpHalfPiPauli(p1*p2,q)
            else return nothing
            end
        end
        _ => nothing
    end
end
