"""
Helper functions to check the first PPM in circuit, determine MeasurementResultType: ClassicalDetermRes, ClassicalRandomRes, QuantumRes
"""
##
using QuantumClifford: project!, Stabilizer, one, GeneralizedStabilizer, tensor_pow, apply!, pcT, projectrand!
using Moshi.Data: variant_name, isa_variant
using StatsBase: wsample
using Accessors: @reset
##

function validate_input(circuit::Circuit, input::Stabilizer)
    if get_circuit_width(circuit)<length(input[1])
        throw(ArgumentError("Input state has more qubits than circuit input"))
    else
        nothing
    end
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

Function that performs commutation and dependency checks on Pauli Product Measurement according to stabilizer list

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
function get_measurement_result(state::CompilerState, op::CircuitOp.Type)
    @debug "Measuring" op _group=:api
    rt = state.runtime
    check_list=state.stabilizer_group
    num_qubits = get_circuit_width(state.circuit)
    len=length(check_list)
    projection = check_PPM(check_list, op, num_qubits)
    if projection === nothing
        return nothing
    else
        if projection[3] === nothing
            if projection[2]<=len
                result = rand(Bool[0,1])
                @debug "This measurement outputs Classical Random Result" _group=:api
                q_1=[1:get_circuit_width(state.circuit);]
                Q_1=ExpQuatPiPauli(check_list[projection[2]],q_1)
                p_2=(-1)^result*op.pauli
                Q_2=ExpQuatPiPauli(p_2,op.qubits)
                pushfirst!(state.circuit,Q_1,Q_2,Q_1)
                preprocess_circuit(state.circuit)
                return (ClassicalRandomRes(op.pauli, result), state)
            else
                (rt, result) = quantum_measurement(rt, op, num_qubits)
                paulistring=embed(size(state.stabilizer_group)[2], op.qubits, op.pauli)
                a_stabilizer= Stabilizer([paulistring])
                check_list=vcat(check_list,a_stabilizer)
                @reset state.stabilizer_group = check_list
                @reset state.runtime = rt
                return (QuantumRes(op.pauli, result), state)
            end
        else
            result = Bool(projection[3]>>1)
            @debug "This measurement outputs Classical Deterministic Result" _group=:api
            return (ClassicalDetermRes(op.pauli, result), state)
        end
    end
end
##
"""
    quantum_measurement(state::SimRuntime, op::CircuitOp.Type, num_qubits::Int) -> Tuple{SimRuntime, Bool}
Perform quantum measurement simulation on given state using QuantumClifford.jl backend
"""
function quantum_measurement(rt::SimRuntime, op::CircuitOp.Type, num_qubits::Int)
    magicqubits = collect(num_qubits-length(rt.quantum_memory.stab)+1:num_qubits)
    quantum_state = rt.quantum_memory
    if quantum_state === nothing
        throw(ArgumentError("Magic State not initiated"))
    else
        real_p=op.pauli[magicqubits]
        bit_result = projectrand!(quantum_state, real_p)[2]
        result=Bool(bit_result>>1)
        rt = @reset rt.quantum_memory = quantum_state
        return (rt, result)
    end
end

"""
    quantum_measurement(state::DummyRuntime, op::CircuitOp.Type, num_qubits::Int) -> Tuple{DummyRuntime, Bool}
Perform quantum measurement simulation on given state using classical sampling according to weight determined by user named outcome_probs
"""
function quantum_measurement(rt::DummyRuntime, op::CircuitOp.Type, num_qubits::Int)
    outcome_probs = [1-rt.p1_outcome_probs, rt.p1_outcome_probs]
    result = wsample([false,true],outcome_probs)
    return (rt,result)
end

"""Resolve conditional circuit operations defined by CircuitOp.BitConditional within circuit defined in state.circuit"""
function resolve_conditionals(state::CompilerState)
    circuit=state.circuit
    creg=state.classical_register
    index=find_variant_indices(circuit, BitConditional)
    for i in index
        @debug("Start resolving BitConditional at $i")
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
