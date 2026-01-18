"""
Functions for querying which qubits are affected by circuit operations.
"""

"""
    affectedqubits(op::CircuitOp.Type) -> Vector{Int}

Return the sorted list of qubit indices affected by a circuit operation.

Uses pattern matching on the CircuitOp ADT variants to extract qubit information.

# Examples
```julia
op = Pauli(P"XY", [1, 2])
affectedqubits(op)  # returns [1, 2]

op = PauliConditional(P"X", [1], P"Z", [3])
affectedqubits(op)  # returns [1, 3]
```
"""
function affectedqubits(op::CircuitOp.Type)
    qubits = @match op begin
        CircuitOp.Measurement(pauli, bit, qubits) => qubits
        CircuitOp.Pauli(pauli, qubits) => qubits
        CircuitOp.ExpHalfPiPauli(pauli, qubits) => qubits
        CircuitOp.ExpQuatPiPauli(pauli, qubits) => qubits
        CircuitOp.ExpEighPiPauli(pauli, qubits) => qubits
        CircuitOp.PrepMagic(qubit, qubits) => vcat([qubit], qubits)
        CircuitOp.PauliConditional(cp, cq, tp, tq) => vcat(cq, tq)
        CircuitOp.BitConditional(inner_op, bit) => affectedqubits(inner_op)
    end
    return sort(unique(qubits))
end

"""
    affectedqubits(circuit::Circuit) -> Vector{Int}

Return the sorted list of all qubit indices affected by any operation in the circuit.
"""
function affectedqubits(circuit::Circuit)
    isempty(circuit) && return Int[]
    all_qubits = reduce(vcat, affectedqubits(op) for op in circuit)
    return sort(unique(all_qubits))
end
