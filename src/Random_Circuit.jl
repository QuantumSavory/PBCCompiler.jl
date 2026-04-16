using Random: randstring
using StatsBase: sample
using QuantumClifford: random_pauli
##
"""
    generate_random_circuit(num_ops::Int, num_qubits::Int) -> Circuit

Generate a random circuit with `num_ops` gate operations followed by one
measurement per qubit.

Every operation acts on all qubits (`qubits = collect(1:num_qubits)`).
All Pauli operators have length `num_qubits` and are guaranteed to be
non-identity (at least one X or Z component is set).

For `PauliConditional`, the qubits are split at a random cut point:
qubits 1..k are the control registers and qubits k+1..num_qubits are the
target registers. Requires `num_qubits >= 2` to generate `PauliConditional`
ops; if `num_qubits == 1` only the Exp* op types are used.
"""
function generate_random_circuit(num_ops::Int, num_qubits::Int)::Circuit
    qubits = collect(1:num_qubits)

    # Return a random non-identity PauliOperator of length n.
    function nonid_pauli(n; nophase=true)
        while true
            p = random_pauli(n; nophase=nophase)
            if !iszero(p.xz)
                return p
            end
        end
    end

    ops = CircuitOp.Type[]

    for _ in 1:num_ops
        # When num_qubits == 1 there is no room to split for PauliConditional.
        op_type = (num_qubits >= 2) ? rand(1:4) : rand(1:3)
        p = nonid_pauli(num_qubits; nophase=false)
        if op_type == 1
            push!(ops, CircuitOp.ExpHalfPiPauli(p, qubits))
        elseif op_type == 2
            push!(ops, CircuitOp.ExpQuatPiPauli(p, qubits))
        elseif op_type == 3
            push!(ops, CircuitOp.ExpEighPiPauli(p, qubits))
        else
            # Split 1:num_qubits at a random index so both parts are non-empty.
            split = rand(1:num_qubits - 1)
            control_q = qubits[1:split]
            target_q  = qubits[split+1:end]
            control_p = nonid_pauli(length(control_q); nophase=true)
            target_p  = nonid_pauli(length(target_q);  nophase=true)
            push!(ops, CircuitOp.PauliConditional(control_p, control_q, target_p, target_q))
        end
    end

    for i in 1:num_qubits
        p = nonid_pauli(num_qubits; nophase=true)
        push!(ops, CircuitOp.Measurement(p, i, qubits))
    end

    return ops
end
