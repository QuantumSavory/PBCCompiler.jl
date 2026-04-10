function preprocess_circuit(circuit::Circuit)
    remove_pauliconditional(circuit)
    group_nonclifford(circuit)
    merge_ops(circuit)
    remove_clifford(circuit)
    remove_nonclifford(circuit)
    remove_post_measurement(circuit)
end


function get_CompState(circuit::Circuit, input_state::Stabilizer)
    num_pauli_qubits=get_circuit_width(circuit)
    PauliQubits=Int[1:num_pauli_qubits;]
    preprocess_circuit(circuit)
    MagicQubits=Int[num_pauli_qubits+1: get_circuit_width(circuit);]
    num_bits=get_bit_number(circuit)
    MeasRes=Vector{MeasurementResult}(undef, num_bits)
    creg=Array{Union{Nothing, Bool}}(nothing, num_bits)
    Stabilzier_Group=make_stabilizer_list(input_state, circuit)
    MS=MemoryState(PauliQubits, MagicQubits, MeasRes, Stabilzier_Group, creg)
    CS=ComputerState(circuit, 1, MS)
    return CS
end

"""TODO docstring"""
function do_quantum_step(compstate::ComputerState, runtime::Type{<:QuantumRuntime}=MockRuntime)
    # run the quantum measurement, appropriately updating MemoryState
    circuit=compstate.circuit
    i=compstate.instruction_pointer
    MS=compstate.memory_state
    @debug("Now working with $i th measurement")
    Meas_List = find_measurement_indices(circuit)
    Meas_i=circuit[Meas_List[i]]
    bit_index=Meas_i.bit
    CheckList=MS.StabilizerGroup
    (MR,j)=get_measurement_result(CheckList, Meas_i, get_circuit_width(circuit))
    MS.measurement_results[i]=MR
    MS.classical_register[bit_index]=MR.result
    @match MR.result_type begin
        ClassicalDetermRes() => nothing
        QuantumRes() => begin
            @debug("This measurement outputs Quantum Result")
            paulistring=embed(size(MS.StabilizerGroup)[2], Meas_i.qubits, Meas_i.pauli)
            a_stabilizer= Stabilizer([paulistring])
            StabilizerGroup=vcat(MS.StabilizerGroup,a_stabilizer)
            MS=MemoryState(MS.pauli_qubits, MS.magic_qubits, MS.measurement_results, StabilizerGroup, MS.classical_register)
        end
        ClassicalRandomRes() => begin
            @debug("This measurement outputs Classical Random Result")
            q_1=[1:get_circuit_width(circuit);]
            Q_1=ExpQuatPiPauli(CheckList[j],q_1)
            p_2=(-1)^MR.result*Meas_i.pauli
            Q_2=ExpQuatPiPauli(p_2,Meas_i.qubits)
            pushfirst!(circuit,Q_1,Q_2,Q_1)
            preprocess_circuit(circuit)
        end
    end
    i=i+1
    return ComputerState(circuit, i, MS)
end

"""TODO docstring"""
function run(input_circuit::Circuit, input_state::Stabilizer)
    # run preprocessing
    # prepare ComputerState
    validate_circuit(input_circuit)
    validate_input(input_circuit,input_state)
    CS = get_CompState(input_circuit, input_state)
    len=length(CS.memory_state.classical_register)
    while true && !isempty(CS.circuit)
        @debug("Working on $(CS.instruction_pointer) th PPM")
        # run next_quantum_step and do_quantum_step until there is no next step
        resolve_conditionals(CS)
        @debug("After BitConditional resolved, the circuit becomes: \n$(join(CS.circuit, "\n"))")
        CS=do_quantum_step(CS)
        @debug("Performed $pointer th PPM")
        @debug("After PPM resolved, the circuit becomes: \n$(join(CS.circuit, "\n"))")
        if CS.instruction_pointer>len
            break
        end
        @debug("Current classical register: $(CS.memory_state.classical_register)")
    end
    circuit=[]
    for i in 1:length(CS.circuit)
        op=CS.circuit[i]
        pauli=CS.memory_state.measurement_results[i].pauli
        new_op=CircuitOp.Measurement(pauli,op.bit,op.qubits)
        push!(circuit,new_op)
    end
    return ComputerState(circuit, CS.instruction_pointer, CS.memory_state)
end
