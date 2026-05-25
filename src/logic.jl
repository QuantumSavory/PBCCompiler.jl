    """
    This file contains the main logic for compute and compile input circuit into PBC Circuit
    """


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

"""Get initial ComputerState using input circuit and input state"""
function get_CompState(circuit::Circuit, input_state::Union{Stabilizer, Nothing}=nothing, dummy::Bool=false)
    num_pauli_qubits=get_circuit_width(circuit)
    if isnothing(input_state)
        state=Stabilizer(one(Stabilizer, num_pauli_qubits; basis=:Z))
    else
        state=input_state
    end
    @debug "Number of pauliqubits" num_pauli_qubits _group=:api
    preprocess_circuit(circuit)
    @debug "Circuit after preprocessing: " circuit _group=:api
    stabilzier_group=make_stabilizer_list(state, circuit)
    num_gadgets=size(stabilzier_group)[2]-num_pauli_qubits
    @debug "Number of Magic qubits" num_gadgets _group=:api
    magicstate = num_gadgets==0 || dummy ? nothing : create_magic_state(num_gadgets)
    num_bits=get_bit_number(circuit)
    MeasRes=Vector{MeasurementResult}(undef, num_bits)
    creg=Array{Union{Nothing, Bool}}(nothing, num_bits)
    ms=MemoryState(MeasRes, stabilzier_group, magicstate, creg)
    cs=ComputerState(circuit,num_gadgets, 1, ms, dummy)
    @debug("Initial Circuit: \n$(join(cs.circuit, "\n"))")
    @debug("The initial quantum memory holds $magicstate")
    return cs
end

"""Perform the next joint measurement and update ComputerState accordingly"""
function do_quantum_step(compstate::ComputerState, runtime::Type{<:QuantumRuntime}=MockRuntime)
    # run the quantum measurement, appropriately updating MemoryState
    circuit=compstate.circuit
    num_gadgets=compstate.num_gadgets
    i=compstate.instruction_pointer
    ms=compstate.memory_state
    Dummy=compstate.dummy
    @debug "Now working with $i th measurement" _group=:api
    meas_list = find_variant_indices(circuit,Measurement)
    meas_i=circuit[meas_list[i]]
    bit_index=meas_i.bit
    checklist=ms.StabilizerGroup
    res=get_measurement_result(compstate, meas_i)
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
            paulistring=embed(size(ms.StabilizerGroup)[2], meas_i.qubits, meas_i.pauli)
            a_stabilizer= Stabilizer([paulistring])
            StabilizerGroup=vcat(ms.StabilizerGroup,a_stabilizer)
            ms=MemoryState(ms.measurement_results, StabilizerGroup,quantum_state, ms.classical_register)
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
    i=i+1
    return ComputerState(circuit,num_gadgets, i, ms, Dummy)
end

"""Run compute/compile with provided circuit and input state(described by stabilizer group)"""
function run(input_circuit::Circuit, input_state::Union{Stabilizer, Nothing}=nothing; dummy::Bool=false)
    # run preprocessing
    # prepare ComputerState
    validate_circuit(input_circuit)
    @debug let
        circuit=copy(input_circuit)
        num_q=get_circuit_width(circuit)
        "Circuit before preprocessing: \n$(join(circuit, "\n"))"
        "Initial number of qubits $num_q"
    end _group=:api
    if !isnothing(input_state)
        validate_input(input_circuit,input_state)
    end
    cs = get_CompState(input_circuit, input_state, dummy)
    len=length(cs.memory_state.classical_register)
    while true && !isempty(cs.circuit)
        @debug "Working on $(cs.instruction_pointer) th PPM" _group=:api
        # run next_quantum_step and do_quantum_step until there is no next step
        resolve_conditionals(cs)
        @debug "After BitConditional resolved, the circuit becomes: \n$(join(cs.circuit, "\n"))"
        cs=do_quantum_step(cs)
        @debug "Performed $(cs.instruction_pointer) th PPM" _group=:api
        @debug "Current pointer is $(cs.instruction_pointer), len is $len" _group=:api
        @debug "After PPM resolved, the circuit becomes: \n$(join(cs.circuit, "\n"))"
        @debug "Current classical register: $(cs.memory_state.classical_register)" _group=:api
        if cs.instruction_pointer>len
            break
        end
    end
    @debug "Compute/Compile Complete" _group=:api
    circuit=[]
    for i in 1:length(cs.circuit)
        op=cs.circuit[i]
        pauli=cs.memory_state.measurement_results[i].pauli
        new_op=CircuitOp.Measurement(pauli,op.bit,op.qubits)
        push!(circuit,new_op)
    end
    @debug "Circuit Reordering Complete" _group=:api
    return ComputerState(circuit,cs.num_gadgets, cs.instruction_pointer, cs.memory_state, cs.dummy)
    @debug "Result returned" _group=:api
end
