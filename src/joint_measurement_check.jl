#Helper functions to check the first PPM in circuit, determine MeasurementResultType: ClassicalDetermRes, ClassicalRandomRes, QuantumRes
##
using QuantumClifford: project!, Stabilizer, one, GeneralizedStabilizer, tensor_pow, apply!, pcT, projectrand!
using Moshi.Data: variant_name, isa_variant
using StatsBase
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

"""
    check_PPM(s::Stabilizer,op::CircuitOp.Type, num_qubits::Int) -> Tuple{MixedStabilizer, Int64, Any}

Function that performs commutation and depedency checks on Pauli Product Measurement according to stabilizer list

It returns
- a stabilizer that might not be in canonical form
- the index of the row where the non-commuting operator was (that row is now equal to pauli; its phase is not updated and for a faithful measurement simulation it needs to be randomized by the user)
- and the result of the projection if there was no non-commuting operator (nothing otherwise)

In the case that PPM is commuting and independent, second field will return index = length(Stabilizer)+1, third field nothing
"""
function check_PPM(s::Stabilizer,op::CircuitOp.Type, num_qubits::Int)
    if !isa_variant(op,CircuitOp.Measurement)
        return nothing
    else
        Paulilen = num_qubits
        Pauli = embed(Paulilen, op.qubits, op.pauli)
        return project!(copy(s),Pauli)
    end
end

"""
    get_measurement_result(state::S, op::CircuitOp.Type) where S <: AbstractSimState -> Tuple{MeasurementResult, Int64, GeneralizedStabilizer}

Perform Joint Measurement on a CircuitOp.Measurement

It returns
- a MeasurementResult with corresponding MeasurementResultType
- the index of the row where the non-commuting operator was (that row is now equal to pauli; its phase is not updated and for a faithful measurement simulation it needs to be randomized by the user)
- a GeneralizedStabilizer represents the quantum state after measurement
"""
function get_measurement_result(state::S, op::CircuitOp.Type) where S <: AbstractSimState
    @debug "Measuring" op _group=:api
    ms=state.memory_state
    s=ms.stabilizer_group
    num_qubits = get_circuit_width(state.circuit)
    len=length(s)
    projection = check_PPM(s, op, num_qubits)
    if projection === nothing
        return nothing
    else
        if projection[3] === nothing
            if projection[2]<=len
                result = rand(Bool[0,1])
                return (classical_random_result(op.pauli, result), projection[2], ms.quantum_memory)
            else
                (quantum_state, result) = quantum_measurement(state, op, num_qubits)
                return (quantum_result(op.pauli, result), projection[2], quantum_state)
            end
        else
            result = Bool(projection[3]>>1)
            return (classical_deterministic_result(op.pauli, result), projection[2], ms.quantum_memory)
        end
    end
end

##
"""
    quantum_measurement(state::ComputerState, op::CircuitOp.Type, num_qubits::Int) -> Tuple{GeneralizedStabilizer, Bool}
Perform quantum measurement simulation on given state using QuantumClifford.jl backend
"""
function quantum_measurement(state::SimState, op::CircuitOp.Type, num_qubits::Int)
    magicqubits = collect(num_qubits-state.num_gadgets+1:num_qubits)
    quantum_state = state.memory_state.quantum_memory
    if quantum_state === nothing
        throw(ArgumentError("Magic State not initiated"))
    else
        real_p=op.pauli[magicqubits]
        bit_result = projectrand!(quantum_state, real_p)[2]
        result=Bool(bit_result>>1)
        return (quantum_state, result)
    end
end

"""
    quantum_measurement(state::DummyState, op::CircuitOp.Type, num_qubits::Int) -> Tuple{GeneralizedStabilizer, Bool}
Perform quantum measurement simulation on given state using classical sampling according to weight determined by user named outcome_probs
"""
function quantum_measurement(state::DummyState, op::CircuitOp.Type, num_qubits::Int)
    quantum_state = state.memory_state.quantum_memory
    result = wsample([false,true],state.outcome_probs)
    return (quantum_state,result)
end

"""Resolve conditional circuit operations defined by CircuitOp.BitConditional within circuit defined in state.circuit"""
function resolve_conditionals(state::S) where S <: AbstractSimState
    circuit=state.circuit
    ms=state.memory_state
    creg=ms.classical_register
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
