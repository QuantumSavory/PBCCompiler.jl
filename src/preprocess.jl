#Functions for compiling quantum circuits by moving measurement operations to the beginning of the circuit.
##
using Moshi.Data: variant_name, isa_variant
using Moshi.Match: @match
using QuantumClifford: PauliOperator, @P_str, embed, tensor, @S_str, Stabilizer
using Random: randstring
##
struct PauliQubitMismatchError <: Exception
    msg::String
end

"""
Validate a single circuit operation, throwing a descriptive error for inputs the
compilation pipeline cannot process: Pauli/qubit length mismatches, imaginary
(±i) Pauli phases, empty qubit lists, non-positive qubit or classical bit
indices, overlapping PauliConditional registers, and PrepMagic (not yet
supported by the pipeline).
"""
function validate_CircuitOp(op::CircuitOp.Type)
    @match op begin
        CircuitOp.PauliConditional(cp, cq, tp, tq) => begin
            if cq == Int64[] || tq == Int64[]
                throw(PauliQubitMismatchError("PauliConditional($cp, $cq, $tp, $tq): control and target qubit lists can't be empty"))
            end
            if !isempty(intersect(cq, tq))
                throw(ArgumentError("PauliConditional($cp, $cq, $tp, $tq): control and target qubit registers overlap; the decomposition into Pauli Product Rotations requires disjoint registers"))
            end
            validate_CircuitOp(ExpQuatPiPauli(cp, cq))
            validate_CircuitOp(ExpQuatPiPauli(tp, tq))
        end
        CircuitOp.PrepMagic(qubit, qubits) => begin
            throw(ArgumentError("PrepMagic($qubit, $qubits) is not supported by the compilation pipeline; non-Clifford rotations are gadgetized automatically instead"))
        end
        CircuitOp.BitConditional(inner_op, bit) => begin
            if bit < 1
                throw(ArgumentError("BitConditional(…, $bit): classical bit indices must be ≥ 1"))
            end
            validate_CircuitOp(inner_op)
        end
        _ => begin
            p=paulis(op)
            q=affectedqubits(op)
            name=variant_name(op)
            if isempty(q)
                throw(PauliQubitMismatchError("$name($p, $q): operation affects no qubits"))
            end
            if any(<(1), q)
                throw(ArgumentError("$name($p, $q): qubit indices must be ≥ 1"))
            end
            if length(p) != length(q)
                throw(PauliQubitMismatchError("$name($p, $q): The length of the Pauli string is not the same as the number of affected qubits. Please check the input operation."))
            end
            # Odd phase exponents (0x01/0x03) denote ±i·P, which is not Hermitian
            # and therefore not a valid rotation axis or measurement observable
            if isodd(p.phase[])
                throw(ArgumentError("$name($p, $q): Pauli strings with imaginary phase (±i) are not Hermitian and cannot define a rotation or measurement."))
            end
            if isa_variant(op, CircuitOp.Measurement) && op.bit < 1
                throw(ArgumentError("$name($p, $q): classical bit indices must be ≥ 1, got $(op.bit)"))
            end
        end
    end
end

"""
Validate every CircuitOp in a circuit (see `validate_CircuitOp`), plus the
circuit-level invariants the runtime relies on: measurement bit indices must be
distinct (a duplicate would silently drop a measurement), and every
BitConditional must be controlled by a bit that some Measurement writes.
"""
function validate_circuit(circuit::Circuit)
    for op in circuit
        validate_CircuitOp(op)
    end
    meas_indices = find_variant_indices(circuit, Measurement)
    bits = [circuit[i].bit for i in meas_indices]
    if !allunique(bits)
        throw(ArgumentError("Duplicate classical bit indices among measurements ($bits): each Measurement must write a distinct bit"))
    end
    bitset = Set(bits)
    for i in find_variant_indices(circuit, BitConditional)
        b = circuit[i].bit
        if !(b in bitset)
            throw(ArgumentError("BitConditional at position $i is controlled by bit $b, which no Measurement in the circuit writes"))
        end
    end
end

function get_circuit_width(circuit::Circuit)
    width=0
    for i in circuit
        width=max(width,maximum(affectedqubits(i)))
    end
    return width
end

function get_bit_number(circuit::Circuit)
    num_bit=0
    for i in find_variant_indices(circuit,Measurement)
        bits = @match circuit[i] begin
            CircuitOp.Measurement(pauli, bit, qubits) => bit
            _ => nothing
        end
        num_bit = max(num_bit,bits)
    end
    return num_bit
end

function find_variant_indices(vec, ::Type{T}) where T
    findall(x -> isa_variant(x, T), vec)
end

"""
Function that replace a non-Clifford circuit operation with BitConditional CircuitOps
Each BitConditional CircuitOp contains a gadget(a set of four consecutive CircuitOps) for pi/8 rotation implementation:
    Realize pi/8 rotation by consuming a |T ⟩ ancilla state
    perform a joint measurement P ⊗ Z between data and ancilla,
    then apply a conditional Clifford correction
"""
function gadgetize(op::CircuitOp.Type, num_input_qubit::Int, num_bit::Int, num_magic_state::Int)
    if isa_variant(op,CircuitOp.ExpEighPiPauli)
        P=paulis(op)
        Q=affectedqubits(op)
        magic_state=[num_input_qubit+num_magic_state]
        pauli=tensor(P,P"Z")
        qubit=[Q;magic_state]
        magic_bit_1=num_bit+2*num_magic_state-1
        magic_bit_2=num_bit+2*num_magic_state
        measurement_1=CircuitOp.Measurement(pauli,magic_bit_1,qubit)
        measurement_2=CircuitOp.Measurement(P"X", magic_bit_2, magic_state)
        bitconditional_1=CircuitOp.BitConditional(CircuitOp.ExpQuatPiPauli(P,Q),magic_bit_1)
        bitconditional_2=CircuitOp.BitConditional(CircuitOp.ExpHalfPiPauli(P,Q),magic_bit_2)
        gadget=[measurement_1, measurement_2, bitconditional_1, bitconditional_2]
        return gadget
    else
        nothing
    end
end


"""
s is the stabilized part of input_state defined by user in the form of a stabilzier group
Function will expand the stabilizer group to cover the entire circuit width by adding Identities to each stabilizer
"""
function make_stabilizer_list(s::Stabilizer, circuit::Circuit)
    paulilen=get_circuit_width(circuit)
    num_pauli_qubits = length(s)
    new_s=PauliOperator[]
    pauli_qubits = collect(1:num_pauli_qubits)
    for i in s
        new_i = embed(paulilen, pauli_qubits, i)
        push!(new_s,new_i)
    end
    return Stabilizer(new_s)
end

##
"""
    remove_pauliconditional(circuit::Circuit)->Nothing

Reweite P1-controlled-P2 gates as C(P1, P2) = (P1 ⊗ P2)π/4 · (1 ⊗ P2)−π/4 · (P1 ⊗ 1)−π/4.

**Kernel class:** expanding transformation (1→3)
**Traversal:** inline — traversal and kernel logic are co-located in this
function, mutates in place.
"""
function remove_pauliconditional(circuit::Circuit)
    indices=find_variant_indices(circuit,PauliConditional)
    for i in reverse(indices)
        op=circuit[i]
        @match op begin
            CircuitOp.PauliConditional(cp, cq, tp, tq) => begin
                op_1=CircuitOp.ExpQuatPiPauli(-cp, cq)
                op_2=CircuitOp.ExpQuatPiPauli(-tp, tq)
                op_3=CircuitOp.ExpQuatPiPauli(cp⊗tp, sort(union(cq, tq)))
                splice!(circuit, i, (op_3, op_2, op_1))
            end
            _ => nothing
        end
    end
end

"""
    group_nonclifford(circuit::Circuit)->nothing

**Kernel class:** pair transformation (2→2)
**Traversal:** `traversal` — iterates over consecutive gate pairs,
mutates in place.
"""
function group_nonclifford(circuit::Circuit)
    if find_variant_indices(circuit,ExpEighPiPauli) != []
        for index in find_variant_indices(circuit,ExpEighPiPauli)
            circuit=traversal(circuit, conjugate_noncliff, :left, 1, index-1)
        end
    end
end

"""
    merge_ops(circuit::Circuit)->Nothing

Identifies and combines identical Pauli rotations:
For example, two PPR (π/8) on the same Pauli operator P are merged into a single Clifford-level PPR (π/4).
A rotation and its inverse, PPR (π/8) and PPR (−π/8), cancel each other out completely and are removed.

**Kernel class:** pair transformation (2→2)
**Traversal:** `traversal` — iterates over consecutive gate pairs,
mutates in place.
    """
function merge_ops(circuit::Circuit)
    traversal(circuit,merge_rotations, :left, 1, :end)
end

"""
    remove_clifford(circuit::Circuit)->Nothing

**Kernel class:** pair transformation (2→2)
**Traversal:** `traversal` — iterates over consecutive gate pairs,
mutates in place.
"""
function remove_clifford(circuit::Circuit)
    for index in find_variant_indices(circuit, Measurement)
        circuit=traversal(circuit, conjugate_measurement, :left, 1, index-1)
    end
    return circuit
end

"""
    remove_nonclifford(circuit::Circuit)->Nothing

Replace every non-Clifford rotation with its magic-state gadget (see `gadgetize`).

**Kernel class:** expanding transformation (1→4)
**Traversal:** inline — traversal and kernel logic are co-located in this
function, mutates in place.
"""
function remove_nonclifford(circuit::Circuit)
    indices=find_variant_indices(circuit,ExpEighPiPauli)
    num_input_qubit=get_circuit_width(circuit)
    num_bit=max(get_bit_number(circuit), num_input_qubit)
    num_magic_state=0
    for i in reverse(indices)
        num_magic_state+=1
        op=circuit[i]
        gadget = gadgetize(op, num_input_qubit, num_bit, num_magic_state)
        splice!(circuit, i, gadget)
    end
end

"""
    remove_post_measurement(circuit::Circuit) -> Nothing

Removes all gates after last CircuitOp.Measurement. No traversal+kernel structure;
operates directly on the underlying gate sequence.
"""
function remove_post_measurement(circuit::Circuit)
    indices=find_variant_indices(circuit,Measurement)
    isempty(indices) && return circuit
    resize!(circuit, maximum(indices))
end
