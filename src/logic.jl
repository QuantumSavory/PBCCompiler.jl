#This file contains the main logic for compute and compile input circuit into PBC Circuit
using Accessors: @reset
"""
Process a Clifford + T circuit into a Pauli Product circuit by appropriately commuting
all Clifford gates past the nonClifford-gates and absorbing them in the Pauli Product Measurements.
Then replace all nonClifford Pauli Product Rotations with gadgets.
"""
function preprocess_circuit(circuit::Circuit)
    if isempty(circuit) || length(circuit) < 2
        return circuit
    end
    remove_pauliconditional(circuit)
    group_nonclifford(circuit)
    merge_ops(circuit)
    remove_clifford(circuit)
    remove_nonclifford(circuit)
    remove_post_measurement(circuit)
end

"""
    get_CompState(circuit::Circuit, input_state::Union{Stabilizer, Nothing}=nothing, dummy::Bool=false) -> AbstractSimState

Get initial Execution State using input circuit and input state.

# Fields
- `circuit`: input circuit for compilation
- `input_state`: initial qubit state
- `dummy`: flag for running dummy simulation
- `outcome_probs`: 2-element distribution vector [p_p1, p_m1]. p_p1 is the probability measuring +1; p_m1 is the probability measuring -1
"""
function get_CompState(circuit::Circuit, input_state::Union{Stabilizer, Nothing}=nothing; dummy::Bool=false, outcome_probs::Vector{Int}=[1,1])
    validate_circuit(circuit)
    num_pauli_qubits=get_circuit_width(circuit)
    @debug "Initial number of qubits $num_pauli_qubits" _group=:api
    if isnothing(input_state)
        state=Stabilizer(one(Stabilizer, num_pauli_qubits; basis=:Z))
    else
        validate_input(circuit,input_state)
        state=input_state
    end
    preprocess_circuit(circuit)
    stabilzier_group=make_stabilizer_list(state, circuit)
    num_gadgets=size(stabilzier_group)[2]-num_pauli_qubits
    @debug "Number of gadgets inserted" num_gadgets _group=:api
    magicstate = num_gadgets==0 || dummy ? nothing : create_magic_state(num_gadgets)
    num_bits=get_bit_number(circuit)
    MeasRes=Vector{MeasurementResult}(undef, num_bits)
    creg=Array{Union{Nothing, Bool}}(nothing, num_bits)
    ms=MemoryState(MeasRes, stabilzier_group, magicstate, creg)
    if dummy
        return DummyState(circuit, num_gadgets, 1, ms, outcome_probs)
    else
        return ComputerState(circuit,num_gadgets, 1, ms)
    end
end

"""Perform the next joint measurement and update ComputerState accordingly"""
function do_quantum_step(state::S, runtime::Type{<:QuantumRuntime}=MockRuntime) where S <: AbstractSimState
    # run the quantum measurement, appropriately updating MemoryState
    circuit = state.circuit
    i=state.instruction_pointer
    ms=state.memory_state
    @debug "Now working with $i th measurement" _group=:api
    meas_list = find_variant_indices(circuit,Measurement)
    meas_i=circuit[meas_list[i]]
    bit_index=meas_i.bit
    checklist=ms.stabilizer_group
    res=get_measurement_result(state, meas_i)
    @debug "Measurement result is $res" _group=:api
    MR=res[1]
    j=res[2]
    ms.measurement_results[i]=MR
    ms.classical_register[bit_index]=MR.result
    @match MR.result_type begin
        ClassicalDetermRes() => nothing
        QuantumRes() => begin
            @debug "This measurement outputs Quantum Result" _group=:api
            quantum_state=res[3]
            paulistring=embed(size(ms.stabilizer_group)[2], meas_i.qubits, meas_i.pauli)
            a_stabilizer= Stabilizer([paulistring])
            stabilizer_group=vcat(ms.stabilizer_group,a_stabilizer)
            @reset ms.stabilizer_group = stabilizer_group
            @reset ms.quantum_memory = quantum_state
        end
        ClassicalRandomRes() => begin
            @debug "This measurement outputs Classical Random Result" _group=:api
            q_1=[1:get_circuit_width(circuit);]
            Q_1=ExpQuatPiPauli(checklist[j],q_1)
            p_2=(-1)^MR.result*meas_i.pauli
            Q_2=ExpQuatPiPauli(p_2,meas_i.qubits)
            pushfirst!(circuit,Q_1,Q_2,Q_1)
            preprocess_circuit(circuit)
        end
    end
    @reset state.instruction_pointer = i+1
    @reset state.memory_state = ms
end

"""Run compute/compile with provided circuit and input state(described by stabilizer group)"""
function run(input_circuit::Circuit, input_state::Union{Stabilizer, Nothing}=nothing; dummy::Bool=false, outcome_probs::Vector{Int}=[1,1])
    state = get_CompState(input_circuit, input_state; dummy=dummy, outcome_probs=outcome_probs)
    len=length(state.memory_state.classical_register)
    while true && !isempty(state.circuit)
        @debug "Working on $(state.instruction_pointer) th PPM" _group=:api
        resolve_conditionals(state)
        state=do_quantum_step(state)
        @debug "Performed $(state.instruction_pointer) th PPM" _group=:api
        @debug "Current classical register: $(state.memory_state.classical_register)" _group=:api
        if state.instruction_pointer>len
            break
        end
    end
    @debug "Compute/Compile Complete" _group=:api
    pbc_circuit=[]
    for i in 1:length(state.circuit)
        op=state.circuit[i]
        pauli=state.memory_state.measurement_results[i].pauli
        new_op=CircuitOp.Measurement(pauli,op.bit,op.qubits)
        push!(pbc_circuit,new_op)
    end
    return @reset state.circuit = pbc_circuit
    @debug "Result returned" _group=:api
end
