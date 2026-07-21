#This file contains the main logic for compute and compile input circuit into PBC Circuit
using Accessors: @reset
"""
    preprocess_circuit(circuit::Circuit) -> Circuit

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
    get_compilerstate(input_circuit::Circuit, rt::S, input_state::Union{Stabilizer, Nothing}=nothing) where S <: AbstractRuntime

Get initial Execution State using input circuit and input state.

# Fields
- `circuit`: input circuit for compilation
- 'rt': runtime for compilation
- `input_state`: initial qubit state
"""
##
function build_compilerstate(input_circuit::Circuit, rt::S, input_state::Union{Stabilizer, Nothing}=nothing) where S <: AbstractRuntime
    validate_circuit(input_circuit)
    if isnothing(input_state)
        input_state=Stabilizer(one(Stabilizer, get_circuit_width(input_circuit); basis=:Z))
    else
        validate_input(input_circuit,input_state)
        input_state=input_state
    end
    shared = build_shared(input_circuit, input_state)
    rt_data = build_rt_data(input_circuit, input_state, rt)
    CompilerState(; shared..., runtime=rt_data)
end
##
function build_shared(input_circuit::Circuit, input_state::Stabilizer)
    circuit = copy(input_circuit)
    preprocess_circuit(circuit)
    num_bits=get_bit_number(circuit)
    measres=Vector{MeasurementResult.Type}(undef, num_bits)
    creg=Array{Union{Nothing, Bool}}(nothing, num_bits)
    stabgroup=make_stabilizer_list(input_state, circuit)
    return (measurement_results = measres, classical_register = creg, stabilizer_group = stabgroup, circuit = circuit, instruction_pointer = 1)
end
##
function build_rt_data(input_circuit::Circuit, input_state::Stabilizer, rt::SimRuntime)
    num_pauli_qubits=get_circuit_width(input_circuit)
    circuit = copy(input_circuit)
    preprocess_circuit(circuit)
    stabilizer_group=make_stabilizer_list(input_state, circuit)
    num_gadgets=size(stabilizer_group)[2]-num_pauli_qubits
    quantum_memory = num_gadgets==0 ? nothing : create_magic_state(num_gadgets)
    @debug "Number of gadgets inserted" num_gadgets _group=:api
    @reset rt.quantum_memory=quantum_memory
    return rt
end

function build_rt_data(input_circuit::Circuit, input_state::Stabilizer, rt::DummyRuntime)
    return rt
end

"""
    do_quantum_step(state::S) -> S where S <: AbstractSimState

Perform the next joint measurement and update ComputerState accordingly
"""
function do_quantum_step(state::CompilerState)
    circuit = state.circuit
    i=state.instruction_pointer
    @debug "Now working with $i th measurement" _group=:api
    meas_list = find_variant_indices(circuit, Measurement)
    op=circuit[meas_list[i]]
    bit_index=op.bit
    (meas_result, state)=get_measurement_result(state, op)
    @debug "Measurement result is $res" _group=:api
    state.measurement_results[i]=meas_result
    state.classical_register[bit_index]=meas_result.result
    @reset state.instruction_pointer = i+1
end

"""
    run(input_circuit::Circuit, rt::S, input_state::Union{Stabilizer, Nothing}=nothing) where S <: AbstractRuntime

Run compute/compile with provided circuit and input state(described by stabilizer group)
# Fields
- `circuit`: input circuit for compilation
- 'rt': runtime used for current compilation
- `input_state`: initial qubit state
"""
function run(input_circuit::Circuit, rt::S, input_state::Union{Stabilizer, Nothing}=nothing) where S <: AbstractRuntime
    state = build_compilerstate(input_circuit, rt, input_state)
    len=length(state.classical_register)
    while !isempty(state.circuit)
        @debug "Working on $(state.instruction_pointer) th PPM" _group=:api
        resolve_conditionals(state)
        state=do_quantum_step(state)
        @debug "Performed $(state.instruction_pointer) th PPM" _group=:api
        @debug "Current classical register: $(state.classical_register)" _group=:api
        if state.instruction_pointer>len
            break
        end
    end
    @debug "Compute/Compile Complete" _group=:api
    return state
end
