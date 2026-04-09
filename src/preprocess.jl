"""
Functions for compiling quantum circuits by moving measurement operations to the beginning of the circuit.
"""
struct PauliQubitMismatchError <: Exception
    msg::String
end

function validate_CircuitOp(op::CircuitOp.Type)
    p=affectedpaulis(op)
    q=affectedqubits(op)
    name=variant_name(op)
    if length(p) != length(q)
        throw(PauliQubitMismatchError("$name($p, $q): The length of the Pauli string is not the same as the number of affected qubits. Please check the input operation."))
    end
    @match op begin
        CircuitOp.PauliConditional(cp, cq, tp, tq) => begin
            if cq == Int64[] || tq == Int64[]
                throw(PauliQubitMismatchError("$name($p, $q): Pauli String can't be empty"))
            end
        end
        _ => nothing
    end
end

function validate_circuit(circuit::Circuit)
    for op in circuit
        validate_CircuitOp(op)
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
    for i in find_measurement_indices(circuit)
        bits = @match circuit[i] begin
            CircuitOp.Measurement(pauli, bit, qubits) => bit
            _ => nothing
        end
        num_bit = max(num_bit,bits)
    end
    return num_bit
end

function find_measurement_indices(circuit::Circuit)
    measurement_indices = []
    for (index, op) in enumerate(circuit)
        if isa_variant(op,CircuitOp.Measurement)
            push!(measurement_indices, index)
        else
            nothing
        end
    end
    return measurement_indices
end

function find_nonclifford_indices(circuit::Circuit)
    nonclifford_indices = []
    for (index, op) in enumerate(circuit)
        if isa_variant(op, CircuitOp.ExpEighPiPauli)
            push!(nonclifford_indices, index)
        end
    end
    return nonclifford_indices
end


function gadgetize(circuit::Circuit, index::Int, num_input_qubit::Int, num_magic_state::Int)
    op=circuit[index]
    num_bit=get_bit_number(circuit)
    if isa_variant(op,CircuitOp.ExpEighPiPauli)
        P=affectedpaulis(op)
        Q=affectedqubits(op)
        magic_state=[num_input_qubit+num_magic_state]
        Pauli=tensor(P,P"Z")
        Qubit=[Q;magic_state]
        magic_bit_1=num_bit+2*num_magic_state-1
        magic_bit_2=num_bit+2*num_magic_state
        Measurement_1=CircuitOp.Measurement(Pauli,magic_bit_1,Qubit)
        Measurement_2=CircuitOp.Measurement(P"X", magic_bit_2, magic_state)
        BitConditional_1=CircuitOp.BitConditional(CircuitOp.ExpQuatPiPauli(P,Q),magic_bit_1)
        BitConditional_2=CircuitOp.BitConditional(CircuitOp.ExpHalfPiPauli(P,Q),magic_bit_2)
        gadget=[Measurement_1, Measurement_2, BitConditional_1, BitConditional_2]
        splice!(circuit, index, gadget)
    else
        nothing
    end
end

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
