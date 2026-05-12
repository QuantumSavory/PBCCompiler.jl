    """
    This file contains the main logic for compute and compile input circuit into PBC Circuit
    """


"""
Process a Clifford + T circuit into a Pauli Product circuit by appropriately commuting
all Clifford gates past the nonClifford-gates and absorbing them in the Pauli Product Measurements.
Then replace all nonClifford Pauli Product Rotations with gadgets.
"""
function preprocess_circuit(circuit::Circuit)
    _remove_pauliconditional(circuit)
    _group_nonclifford(circuit)
    _merge_ops(circuit)
    _remove_clifford(circuit)
    _remove_nonclifford(circuit)
    _remove_post_measurement(circuit)
end

"""Get initial ComputerState using input circuit and input state"""
function _get_CompState(circuit::Circuit, input_state::Stabilizer, dummy::Bool=false)
    num_pauli_qubits=_get_circuit_width(circuit)
    PauliQubits=Int[1:num_pauli_qubits;]
    @debug "Number of PauliQubits" num_pauli_qubits _group=:api
    preprocess_circuit(circuit)
    @debug "Circuit after preprocessing: " circuit _group=:api
    MagicQubits=Int[num_pauli_qubits+1: _get_circuit_width(circuit);]
    num_magic=length(MagicQubits)
    @debug "Number of Magic qubits" num_magic _group=:api
    MagicState = num_magic==0 || dummy ? nothing : _create_magic_state(num_magic)
    num_bits=_get_bit_number(circuit)
    MeasRes=Vector{MeasurementResult}(undef, num_bits)
    creg=Array{Union{Nothing, Bool}}(nothing, num_bits)
    Stabilzier_Group=_make_stabilizer_list(input_state, circuit)
    MS=MemoryState(PauliQubits, MagicQubits, MeasRes, Stabilzier_Group, MagicState, creg)
    CS=ComputerState(circuit, 1, MS, dummy)
    @debug("Initial Circuit: \n$(join(CS.circuit, "\n"))")
    @debug("The initial quantum memory holds $MagicState")
    return CS
end

"""Perform the next joint measurement and update ComputerState accordingly"""
function _do_quantum_step(compstate::ComputerState, runtime::Type{<:QuantumRuntime}=MockRuntime)
    # run the quantum measurement, appropriately updating MemoryState
    circuit=compstate.circuit
    i=compstate.instruction_pointer
    MS=compstate.memory_state
    Dummy=compstate.dummy
    @debug "Now working with $i th measurement" _group=:api
    Meas_List = find_variant_indices(circuit,Measurement)
    Meas_i=circuit[Meas_List[i]]
    bit_index=Meas_i.bit
    CheckList=MS.StabilizerGroup
    res=get_measurement_result(compstate, Meas_i)
    @debug "Measurement result is $res" _group=:api
    MR=res[1]
    j=res[2]
    MS.measurement_results[i]=MR
    MS.classical_register[bit_index]=MR.result
    @match MR.result_type begin
        ClassicalDetermRes() => nothing
        QuantumRes() => begin
            @debug "This measurement outputs Quantum Result" _group=:api
            quantum_state=res[3]
            paulistring=embed(size(MS.StabilizerGroup)[2], Meas_i.qubits, Meas_i.pauli)
            a_stabilizer= Stabilizer([paulistring])
            StabilizerGroup=vcat(MS.StabilizerGroup,a_stabilizer)
            MS=MemoryState(MS.pauli_qubits, MS.magic_qubits, MS.measurement_results, StabilizerGroup,quantum_state, MS.classical_register)
        end
        ClassicalRandomRes() => begin
            @debug "This measurement outputs Classical Random Result" _group=:api
            q_1=[1:_get_circuit_width(circuit);]
            Q_1=ExpQuatPiPauli(CheckList[j],q_1)
            p_2=(-1)^MR.result*Meas_i.pauli
            Q_2=ExpQuatPiPauli(p_2,Meas_i.qubits)
            pushfirst!(circuit,Q_1,Q_2,Q_1)
            preprocess_circuit(circuit)
        end
    end
    i=i+1
    return ComputerState(circuit, i, MS, Dummy)
end

"""Run compute/compile with provided circuit and input state(described by stabilizer group)"""
function run(input_circuit::Circuit, input_state::Stabilizer, dummy::Bool=false)
    # run preprocessing
    # prepare ComputerState
    _validate_circuit(input_circuit)
    @debug let
        circuit=copy(input_circuit)
        num_q=_get_circuit_width(circuit)
        "Circuit before preprocessing: \n$(join(circuit, "\n"))"
        "Initial number of qubits $num_q"
    end _group=:api
    _validate_input(input_circuit,input_state)
    CS = _get_CompState(input_circuit, input_state, dummy)
    @debug "Number of pauli qubits:" CS.memory_state.pauli_qubits _group=:api
    @debug "Number of magic qubits:" CS.memory_state.magic_qubits _group=:api
    len=length(CS.memory_state.classical_register)
    while true && !isempty(CS.circuit)
        @debug "Working on $(CS.instruction_pointer) th PPM" _group=:api
        # run next_quantum_step and do_quantum_step until there is no next step
        _resolve_conditionals(CS)
        @debug "After BitConditional resolved, the circuit becomes: \n$(join(CS.circuit, "\n"))"
        CS=_do_quantum_step(CS)
        @debug "Performed $(CS.instruction_pointer) th PPM" _group=:api
        @debug "Current pointer is $(CS.instruction_pointer), len is $len" _group=:api
        @debug "After PPM resolved, the circuit becomes: \n$(join(CS.circuit, "\n"))"
        @debug "Current classical register: $(CS.memory_state.classical_register)" _group=:api
        if CS.instruction_pointer>len
            break
        end
    end
    @debug "Compute/Compile Complete" _group=:api
    circuit=[]
    for i in 1:length(CS.circuit)
        op=CS.circuit[i]
        pauli=CS.memory_state.measurement_results[i].pauli
        new_op=CircuitOp.Measurement(pauli,op.bit,op.qubits)
        push!(circuit,new_op)
    end
    @debug "Circuit Reordering Complete" _group=:api
    return ComputerState(circuit, CS.instruction_pointer, CS.memory_state, CS.dummy)
    @debug "Result returned" _group=:api
end
