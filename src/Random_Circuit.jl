"""
Functions for generating random quantum circuits for testing purposes.
    generate_random_circuit(num_ops::Int, num_qubits::Int) -> Circuit
Generate a random quantum circuit with a specified number of operations and qubits.

# Arguments
- `num_ops::Int`: The number of operations in the generated circuit.
- `num_qubits::Int`: The number of qubits that the operations can act on.

# Returns
A `Circuit` object containing the randomly generated operations.
"""

function generate_random_circuit(num_ops::Int, num_qubits::Int)
    ops = CircuitOp.Type[]
    for i in 1:num_ops
        op_type = rand(1:4)
        qubits = sample((1:num_qubits), rand(1:num_qubits); replace=false, ordered=true)
        p= random_pauli(length(qubits); nophase=false)
        if op_type == 1
            push!(ops, ExpHalfPiPauli(p, qubits))
        elseif op_type == 2
            push!(ops, ExpQuatPiPauli(p, qubits))
        elseif op_type == 3
            push!(ops, ExpEighPiPauli(p, qubits))
        else
            control_q=sample(qubits, rand(1:length(qubits)); replace=false, ordered=true)
            target_q = setdiff(qubits, control_q)
            control_p = random_pauli(length(control_q); nophase=true)
            target_p = random_pauli(length(target_q); nophase=true)
            push!(ops, PauliConditional(control_p, control_q, target_p, target_q))
        end
    end
    for i in 1:num_qubits
        paulis = [P"X", P"Y", P"Z"]
        p = rand(paulis)
        push!(ops, Measurement(p, i, [i]))
    end
    return ops
end

function generate_valid_random_circuit(num_ops::Int, num_qubits::Int, limit::Int)
    for i in 1:limit
        try
            ops = generate_random_circuit(num_ops, num_qubits)
            validate_circuit(ops)
            return(ops)
        catch e
        end
    end
end
