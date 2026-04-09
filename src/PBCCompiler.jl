module PBCCompiler

using Moshi.Data: @data, variant_name, isa_variant
using Moshi.Match: @match
using QuantumClifford: PauliOperator, @P_str, comm, embed, ⊗, random_pauli, tensor, @S_str, Stabilizer, project!
using Random: randstring
using StatsBase: sample

##

"""TODO docstring"""
const P = typeof(P"XYZ")

"""TODO docstring"""
@data CircuitOp begin
    """TODO docstring"""
    struct Measurement
        pauli::P
        bit::Int
        qubits::Vector{Int}
    end
    """TODO docstring"""
    struct Pauli
        pauli::P
        qubits::Vector{Int}
    end
    """TODO docstring"""
    struct ExpHalfPiPauli
        pauli::P
        qubits::Vector{Int}
    end
    """TODO docstring"""
    struct ExpQuatPiPauli
        pauli::P
        qubits::Vector{Int}
    end
    """TODO docstring"""
    struct ExpEighPiPauli
        pauli::P
        qubits::Vector{Int}
    end
    """TODO docstring"""
    struct PrepMagic
        qubit::Int
        qubits::Vector{Int}
    end
    """TODO docstring"""
    struct PauliConditional
        control_pauli::P
        control_qubits::Vector{Int}
        target_pauli::P
        target_qubits::Vector{Int}
    end
    """TODO docstring"""
    struct BitConditional
        op::CircuitOp
        bit::Int
    end
end

"""TODO docstring"""
const Circuit = Vector{CircuitOp.Type}

using .CircuitOp: Measurement, Pauli, ExpHalfPiPauli, ExpQuatPiPauli, ExpEighPiPauli, PrepMagic, PauliConditional, BitConditional

include("traversal.jl")
include("affectedqubits.jl")
include("plotting.jl")
include("pair_transformation.jl")
include("preprocess.jl")
include("Random_Circuit.jl")
##

"""TODO docstring"""
function make_counter()
    var = Ref{Int}()
    var[] = 0
    return function counter()
        var[] += 1
        return var[]
    end
end

##

"""TODO docstring"""
function preprocess_circuit(circuit::Circuit)
    remove_pauliconditional(circuit)
    group_nonclifford(circuit)
    merge_ops(circuit)
    remove_clifford(circuit)
    remove_nonclifford(circuit)
    remove_post_measurement(circuit)
end

"""TODO docstring"""
function remove_pauliconditional(circuit::Circuit)
    len=length(circuit)
    for i in 1:len
        op=circuit[i]
        @match op begin
            PauliConditional(cp, cq, tp, tq) => begin
                op_1=ExpQuatPiPauli(-cp, cq)
                op_2=ExpQuatPiPauli(-tp, tq)
                op_3=ExpQuatPiPauli(cp⊗tp, sort(union(cq, tq)))
                splice!(circuit, i, (op_3, op_2, op_1))
            end
            _ => nothing
        end
    end
end

"""TODO docstring"""
function group_nonclifford(circuit::Circuit)
    if find_nonclifford_indices(circuit) != []
        for index in find_nonclifford_indices(circuit)
            circuit=traversal(circuit, conjugate, :left, 1, index-1)
        end
    end
end

"""TODO docstring"""
function merge_ops(circuit::Circuit)
    traversal(circuit,merge_rotations, :left, 1, :end)
end

"""TODO docstring"""
function remove_clifford(circuit::Circuit)
    validate_circuit(circuit)
    for index in find_measurement_indices(circuit)
        circuit=traversal(circuit, conjugate, :left, 1, index-1)
    end
    return circuit
end

"""TODO docstring"""
function remove_nonclifford(circuit::Circuit)
    num_non_clifford=length(find_nonclifford_indices(circuit))
    num_input_qubit=get_circuit_width(circuit)
    num_magic_state=0
    for i in 1:num_non_clifford
        index=find_nonclifford_indices(circuit)[1]
        num_magic_state=+1
        gadgetize(circuit, index, num_input_qubit, num_magic_state)
    end
end

"""TODO docstring"""
function remove_post_measurement(circuit::Circuit)
    # remove all gates after the last measurement
    index=maximum(find_measurement_indices(circuit))
    resize!(circuit, index)
end

##

"""ADT representing different types of measurement result"""
@data MeasurementResultType begin
    """Denoting measurement results that classically determined by a coin flip"""
    ClassicalDetermRes
    """Denoting measurement results that are classically determined by stored eigenvalues of stabilizers"""
    ClassicalRandomRes
    """Denoting measurement results that require performing actual quantum measurement"""
    QuantumRes
end

using .MeasurementResultType: ClassicalDetermRes, ClassicalRandomRes, QuantumRes

"""Struct holding measurement result value and its type"""
struct MeasurementResult
    """Single bit measurement result in boolean"""
    result::Union{Bool,Nothing}
    """Measurement result type of this result (ClassicalDetermRes, ClassicalRandomRes, QuantumRes)"""
    result_type::MeasurementResultType.Type
end

"""TODO docstring"""
classical_deterministic_result(m::Union{Bool,Nothing}) = MeasurementResult(m, ClassicalDetermRes())
"""TODO docstring"""
classical_random_result(m::Union{Bool,Nothing}) = MeasurementResult(m, ClassicalRandomRes())
"""TODO docstring"""
quantum_result(m::Union{Bool,Nothing}) = MeasurementResult(m, QuantumRes())

"""TODO docstring"""
struct MemoryState
    """TODO docstring"""
    measurement_results::Dict{Int,MeasurementResult}
    """TODO docstring"""
    pauli_qubits::Vector{Int}
    """TODO docstring"""
    pauli_state::P
    """TODO docstring"""
    magic_qubits::Vector{Int}
    """TODO docstring"""
    magic_state::Any
end

"""Struct that contains information describing current quantum state"""
struct test_MemoryState
    """Vector that contains index of all data qubits that hold circuit input"""
    pauli_qubits::Vector{Int}
    """Vector that contains index of all qubits that hold magic states"""
    magic_qubits::Vector{Int}
    """Vector that holds all MeasurementResult"""
    measurement_results::Vector{MeasurementResult}
    """Stabilizer object that describes current quantum state"""
    StabilizerGroup::Stabilizer
    """Vector that holds all classical bits storing corresponding measurement results"""
    classical_register::Vector{Union{Nothing,Bool}}
end


"""Struct that contains current state of compiler"""
struct ComputerState
    """Contain current circuit object"""
    circuit::Circuit
    """Denote the Pauli Product Measurement that is being processed"""
    instruction_pointer::Int
    """Contain current quantum state"""
    memory_state::test_MemoryState
end

include("joint_measurement_check.jl")
##

function get_CompState(circuit::Circuit, input_state::Stabilizer)
    num_pauli_qubits=get_circuit_width(circuit)
    PauliQubits=Int[1:num_pauli_qubits;]
    preprocess_circuit(circuit)
    MagicQubits=Int[num_pauli_qubits+1: get_circuit_width(circuit);]
    num_bits=get_bit_number(circuit)
    MeasRes=Vector{MeasurementResult}(undef, num_bits)
    creg=Array{Union{Nothing, Bool}}(nothing, num_bits)
    Stabilzier_Group=make_stabilizer_list(input_state, circuit)
    MS=test_MemoryState(PauliQubits, MagicQubits, MeasRes, Stabilzier_Group, creg)
    CS=ComputerState(circuit, 1, MS)
    return CS
end

"""TODO docstring"""
function next_quantum_step(compstate::ComputerState)
    while true
        # resolve conditionals
        # find next measurement -- if there is none, return nothing
        # commute measurement through preceding gates
        # check, given knowledge of the memory, whether the measurement is known or 50/50 random
        #   - if yes, store measurement result and update classically-trackable computer state
        #   - if not, break and return the measurement to perform on the quantum computer
    end
end

"""TODO docstring"""
abstract type QuantumRuntime end

"""TODO docstring -- all measurements return `nothing` and classically-trackable states are set as if result was `false`."""
struct MockRuntime <: QuantumRuntime end

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
    MS.measurement_results[bit_index]=MR
    MS.classical_register[bit_index]=MR.result
    @match MR.result_type begin
        ClassicalDetermRes() => nothing
        QuantumRes() => begin
            @debug("This measurement outputs Quantum Result")
            paulistring=embed(size(MS.StabilizerGroup)[2], Meas_i.qubits, Meas_i.pauli)
            a_stabilizer= Stabilizer([paulistring])
            StabilizerGroup=vcat(MS.StabilizerGroup,a_stabilizer)
            MS=test_MemoryState(MS.pauli_qubits, MS.magic_qubits, MS.measurement_results, StabilizerGroup, MS.classical_register)
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
    return CS
end

end # module PBCCompiler
