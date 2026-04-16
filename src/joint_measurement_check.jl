"""
Helper functions to check the first PPM in circuit, determine MeasurementResultType: ClassicalDetermRes, ClassicalRandomRes, QuantumRes
"""
##
using QuantumClifford: project!, Stabilizer, one, GeneralizedStabilizer, tensor_pow, apply!, pcT, projectrand!
using Moshi.Data: variant_name, isa_variant
##

function validate_input(circuit::Circuit, input::Stabilizer)
    if get_circuit_width(circuit)<length(input[1])
        throw(ArgumentError("Input state has more qubits than circuit input"))
    else
        nothing
    end
end

function find_BitConditional_indices(circuit::Circuit)
    BitConditional_indices = []
    for (index, op) in enumerate(circuit)
        if isa_variant(op, CircuitOp.BitConditional)
            push!(BitConditional_indices, index)
        end
    end
    return BitConditional_indices
end

function create_hadamard_basis_state(num_qubit::Int)
    n = num_qubit

    generators = one(Stabilizer, n; basis=:X)

    return Stabilizer(generators)
end

function create_magic_state(num_magic::Int)
    n=num_magic

    generators = GeneralizedStabilizer(create_hadamard_basis_state(n))

    T = tensor_pow(pcT,n)

    apply!(generators,T)

    return generators

end

function check_PPM(s::Stabilizer,op::CircuitOp.Type, num_qubits::Int)
    if !isa_variant(op,CircuitOp.Measurement)
        return nothing
    else
        Paulilen = num_qubits
        Pauli=embed(Paulilen, op.qubits, op.pauli)
        return project!(copy(s),Pauli)
    end
end

"""
0x00 denotes +1 eigenvalue, 0x02 denotes -1 eigenvalue
0 denotes +1 eigenvalue, 1 denotes -1 eigenvalue
false denotes +1 eigenvalue, true denotes -1 eigenvalue
"""

function get_measurement_result(compstate::ComputerState, op::CircuitOp.Type)
    @debug "Measuring" op _group=:api
    dummy=compstate.dummy
    ms=compstate.memory_state
    s=ms.StabilizerGroup
    num_qubits = get_circuit_width(compstate.circuit)
    MagicQubits = ms.magic_qubits
    quantum_state = ms.quantum_memory
    @debug "Current quantum memory holds" quantum_state _group=:api
    len=length(s)
    projection = check_PPM(s, op, num_qubits)
    if projection === nothing
        return nothing
    else
        if projection[3] === nothing
            if projection[2]<=len
                result = rand(Bool[0,1])
                return (classical_random_result(op.pauli, result),projection[2])
            else
                if quantum_state === nothing
                    print(compstate.circuit)
                else
                    real_p=op.pauli[MagicQubits]
                    (quantum_state, result) = quantum_measurement(quantum_state, real_p, dummy)
                    return (quantum_result(op.pauli, Bool(result>>1)),projection[2],quantum_state)
                end
            end
        else
            result = Bool(projection[3]>>1)
            return (classical_deterministic_result(op.pauli, result),projection[2])
        end
    end
end

function quantum_measurement(sm::GeneralizedStabilizer, p::PauliOperator, dummy::Bool)
    if dummy
        return +1
    else
        return projectrand!(sm,p)
    end
end


function resolve_conditionals(compstate::ComputerState)
    CS=compstate
    circuit=CS.circuit
    MS=CS.memory_state
    creg=MS.classical_register
    index=find_BitConditional_indices(circuit)
    for i in index
        @debug("Start resoving BitConditional at $i")
        operation=circuit[i]
        control_bit=creg[operation.bit]
        if control_bit !== nothing
            if control_bit
                @debug("$i has a controlled bit")
                splice!(circuit, i, [operation.op])
                @debug("$i Resolved")
                preprocess_circuit(circuit)
                break
            else
                deleteat!(circuit, i)
                @debug("No correction needed")
                preprocess_circuit(circuit)
                break
            end
        else
            @debug("Control Bit undetermined")
            nothing
        end
    end
end
