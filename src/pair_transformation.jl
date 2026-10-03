
#This file contains pair transformation functions that operate on adjacent pair of CircuitOps


"""
    paulis(op::CircuitOp.Type) -> PauliOperator

Return Pauli string that defines the collective eigen-axis of the operation; a Pauli Product Rotation rotates the multi-qubit state around this axis by an angle phi,
while a Pauli Product Measurement projects the system directly into its collective directional eigenstates

# Examples
```jldoctest
julia> op = PBCCompiler.Pauli(P"XY", [1, 2]);

julia> PBCCompiler.paulis(op)
+ XY
```
```jldoctest
julia> op = PBCCompiler.PauliConditional(P"X", [1], P"Z", [3]);

julia> PBCCompiler.paulis(op)
ERROR: pauli called on PauliConditional — decompose first
```
"""
function paulis(op::CircuitOp.Type)
    pauli = @match op begin
        CircuitOp.Pauli(pauli, qubits) => pauli
        CircuitOp.Measurement(pauli, bit, qubits) => pauli
        CircuitOp.ExpHalfPiPauli(pauli, qubits) => pauli
        CircuitOp.ExpQuatPiPauli(pauli, qubits) => pauli
        CircuitOp.ExpEighPiPauli(pauli, qubits) => pauli
        CircuitOp.PauliConditional(cp, cq, tp, tq) => error("pauli called on PauliConditional — decompose first")
        CircuitOp.BitConditional(inner_op, bit) => paulis(inner_op)
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
    pu1 = paulis(op1)
    pu2 = paulis(op2)
    qu1 = affectedqubits(op1)
    qu2 = affectedqubits(op2)
    affected_qubits = sort(union(qu1,qu2))
    paulilen = maximum(affected_qubits)
    pauli1 = embed(paulilen, op1.qubits, pu1)
    pauli2 = embed(paulilen, op2.qubits, pu2)
    return (pauli1, pauli2)
end

"""
    check_commutation(op1::CircuitOp.Type, op2::CircuitOp.Type) -> Union{Int8, Nothing}

Return 0x00 if the two Pauli Product Rotations/Measurements commute, and return 0x01 if they anticommute.
For inputs containing PauliConditional or BitConditional, the function returns nothing.

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
            (pauli1,pauli2) = complete_paulis(op1, op2)
            commutativity = comm(pauli1,pauli2)
            return commutativity
        end
    end
end

"""
    conjugate_noncliff(op1::CircuitOp.Type, op2::CircuitOp.Type) -> Union{Tuple{CircuitOp.Type, CircuitOp.Type}, Nothing}

Move a non-Clifford CircuitOp op2 pass a Clifford CircuitOp op1 and update op2 by conjugating its pauli string by op1's pauli string.
Will throw an error if op2 is not a ExpEighPiPauli CircuitOp. Return nothing if op1 is not a ExpHalfPiPauli or a ExpQuatPiPauli.

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
```
"""
function conjugate_noncliff(op1::CircuitOp.Type, op2::CircuitOp.Type)
    conjugated_op = @match (op1, op2) begin
        (CircuitOp.ExpHalfPiPauli(), CircuitOp.ExpEighPiPauli()) => begin
            (new_p, new_q) = conjugated_by_ExpHalfPiPauli(op1,op2)
            CircuitOp.ExpEighPiPauli(new_p, new_q)
        end
        (CircuitOp.ExpQuatPiPauli(), CircuitOp.ExpEighPiPauli()) => begin
            (new_p, new_q) = conjugated_by_ExpQuatPiPauli(op1,op2)
            CircuitOp.ExpEighPiPauli(new_p, new_q)
        end
        _=> nothing
    end
    return conjugated_op === nothing ? nothing : (conjugated_op,op1)
end
##

"""
    conjugate_measurement(op1::CircuitOp.Type, op2::CircuitOp.Type) -> Union{Tuple{CircuitOp.Type, CircuitOp.Type}, Nothing}

Move a Measurement CircuitOp op2 past a Clifford CircuitOp op1 and update op2 by conjugating its Pauli string by op1's Pauli string.
Will throw an error if op2 is not a Measurement CircuitOp. Return nothing if op1 is not a ExpHalfPiPauli or a ExpQuatPiPauli.

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
```
"""
function conjugate_measurement(op1::CircuitOp.Type, op2::CircuitOp.Type)
    conjugated_op = @match (op1, op2) begin
        (CircuitOp.ExpHalfPiPauli(), CircuitOp.Measurement()) => begin
            b=op2.bit
            (new_p, new_q) = conjugated_by_ExpHalfPiPauli(op1,op2)
            CircuitOp.Measurement(new_p, b, new_q)
        end
        (CircuitOp.ExpQuatPiPauli(), CircuitOp.Measurement()) => begin
            b=op2.bit
            (new_p, new_q) = conjugated_by_ExpQuatPiPauli(op1,op2)
            CircuitOp.Measurement(new_p, b, new_q)
        end
        _=> nothing
    end
    return conjugated_op===nothing ? nothing : (conjugated_op,op1)
end
##
function conjugated_by_ExpHalfPiPauli(op1::CircuitOp.Type, op2::CircuitOp.Type)
    if check_commutation(op1,op2) == 0
        new_p = complete_paulis(op1, op2)[2]
        new_qm = maximum(sort(union(affectedqubits(op1), affectedqubits(op2))))
        new_q = [x for x in 1:new_qm]
    else
        (pauli1, pauli2) = complete_paulis(op1, op2)
        new_p = -pauli2
        new_qm = maximum(sort(union(affectedqubits(op1), affectedqubits(op2))))
        new_q = [x for x in 1:new_qm]
    end
    return (new_p,new_q)
end

function conjugated_by_ExpQuatPiPauli(op1::CircuitOp.Type, op2::CircuitOp.Type)
    if check_commutation(op1,op2) == 0
        new_p = complete_paulis(op1, op2)[2]
        new_qm = maximum(sort(union(affectedqubits(op1), affectedqubits(op2))))
        new_q = [x for x in 1:new_qm]
    else
        (pauli1, pauli2) = complete_paulis(op1, op2)
        new_p = 1im*pauli1*pauli2
        new_qm = maximum(sort(union(affectedqubits(op1), affectedqubits(op2))))
        new_q = [x for x in 1:new_qm]
    end
    return (new_p,new_q)
end
##
"""
    merge_rotations(op1::CircuitOp.Type, op2::CircuitOp.Type)

Combine an adjacent pair of Pauli Product Rotations about the same axis.

Two rotations of the same angle about the same signed Pauli axis merge into one
rotation of twice the angle. A rotation followed by its inverse (opposite-sign
axis) — or any pair of pi/2 rotations about the same axis, which compose to a
global phase — cancels entirely: the empty tuple `()` is returned so `traversal`
deletes both operations. Returns `nothing` when the pair cannot be merged.
"""
function merge_rotations(op1::CircuitOp.Type, op2::CircuitOp.Type)
    @match (op1,op2) begin
        (ExpEighPiPauli(),ExpEighPiPauli()) => begin
            (p1,p2) = complete_paulis(op1,op2)
            qm = maximum(sort(union(affectedqubits(op1), affectedqubits(op2))))
            q = [x for x in 1:qm]
            if p1.xz == p2.xz
                if xor(p1.phase[1], p2.phase[1]) == 0x02
                    # exp(-i*pi/8*P) * exp(-i*pi/8*(-P)) = identity
                    return ()
                elseif op1.pauli.phase == op2.pauli.phase
                    return ExpQuatPiPauli(p1,q)
                else
                    return nothing
                end
            else return nothing
            end
        end
        (ExpQuatPiPauli(),ExpQuatPiPauli()) => begin
            (p1,p2) = complete_paulis(op1,op2)
            qm = maximum(sort(union(affectedqubits(op1), affectedqubits(op2))))
            q = [x for x in 1:qm]
            if p1.xz == p2.xz
                if xor(p1.phase[1], p2.phase[1]) == 0x02
                    # exp(-i*pi/4*P) * exp(-i*pi/4*(-P)) = identity
                    return ()
                elseif op1.pauli.phase == op2.pauli.phase
                    return ExpHalfPiPauli(p1,q)
                else
                    return nothing
                end
            else return nothing
            end
        end
        (ExpHalfPiPauli(),ExpHalfPiPauli()) => begin
            (p1,p2) = complete_paulis(op1,op2)
            if p1.xz == p2.xz
                # Two pi/2 rotations about the same axis compose to +/-identity
                # (a global phase), regardless of the axis signs
                return ()
            else return nothing
            end
        end
        _ => nothing
    end
end
