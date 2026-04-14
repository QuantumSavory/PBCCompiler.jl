using QuantumClifford: PauliOperator, @P_str, Stabilizer
using Moshi.Data: @data
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
    """Corresponding Pauli String of Measurement"""
    pauli::PauliOperator
    """Single bit measurement result in boolean"""
    result::Union{Bool,Nothing}
    """Measurement result type of this result (ClassicalDetermRes, ClassicalRandomRes, QuantumRes)"""
    result_type::MeasurementResultType.Type
end

"""TODO docstring"""
classical_deterministic_result(p::PauliOperator, m::Union{Bool,Nothing}) = MeasurementResult(p, m, ClassicalDetermRes())
"""TODO docstring"""
classical_random_result(p::PauliOperator, m::Union{Bool,Nothing}) = MeasurementResult(p, m, ClassicalRandomRes())
"""TODO docstring"""
quantum_result(p::PauliOperator, m::Union{Bool,Nothing}) = MeasurementResult(p, m, QuantumRes())


"""Struct that contains information describing current quantum state"""
struct MemoryState
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
    memory_state::MemoryState
end
##
"""TODO docstring"""
abstract type QuantumRuntime end

"""TODO docstring -- all measurements return `nothing` and classically-trackable states are set as if result was `false`."""
struct MockRuntime <: QuantumRuntime end
##
_result_type_str(::ClassicalDetermRes) = "ClassicalDeterministic"
_result_type_str(::ClassicalRandomRes) = "ClassicalRandom"
_result_type_str(::QuantumRes) = "Quantum"
_result_type_str(x) = string(x)

_bool_str(::Nothing) = "nothing"
_bool_str(b::Bool) = string(b)

"""
    show(io, result::ComputerState)

Pretty-print the first four fields of `result.memory_state`:
`pauli_qubits`, `magic_qubits`, `measurement_results`, and `StabilizerGroup`.
"""
function Base.show(io::IO, result::ComputerState)
    ms = result.memory_state
    println(io, "ComputerState")
    println(io, "  Pauli Qubits:    ", ms.pauli_qubits)
    println(io, "  Magic Qubits:    ", ms.magic_qubits)
    n = length(ms.measurement_results)
    println(io, "  Measurements ($n):")
    for (i, m) in enumerate(ms.measurement_results)
        println(io, "    [$i] ", m.pauli,
                    "  →  ", _bool_str(m.result),
                    "  (", _result_type_str(m.result_type), ")")
    end
    print(io, "  Stabilizer Group:\n")
    show(io, ms.StabilizerGroup)
end
