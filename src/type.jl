using QuantumClifford: PauliOperator, @P_str, Stabilizer, GeneralizedStabilizer
using Moshi.Data: @data
using Moshi.Derive: @derive
##
"""TODO docstring"""
const P = typeof(P"XYZ")

"""TODO docstring"""
@data CircuitOp begin
    """Measurement of pauli string P (ie., + XY) on qubits in vector at field "qubits" (ie.,[1,3]), measurement result is stored in classical bit denoted in "bit" """
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
    """Perform Pauli Product Rotation(PPR) in the form of Pφ = exp(−iP φ), where P is pauli string, φ is an angle Perform pi/2 PPR on qubits denoted in Vector qubits"""
    struct ExpHalfPiPauli
        pauli::P
        qubits::Vector{Int}
    end
    """Perform pi/4 PPR on qubits denoted in Vector qubits"""
    struct ExpQuatPiPauli
        pauli::P
        qubits::Vector{Int}
    end
    """Perform pi/8 PPR on qubits denoted in Vector qubits"""
    struct ExpEighPiPauli
        pauli::P
        qubits::Vector{Int}
    end
    """TODO docstring"""
    struct PrepMagic
        qubit::Int
        qubits::Vector{Int}
    end
    """Perform a (pi/2) Pauli rotation (defined by target_pauli) on the target qubits, conditional on the control qubits falling into the -1 eigenspace of control_pauli"""
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

@derive CircuitOp[Hash, Eq, Show]

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

@derive MeasurementResultType[Hash, Eq, Show]

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
    """GeneralizedStabilizer object holding current quantum state within quantum computer"""
    quantum_memory::Union{GeneralizedStabilizer, Nothing}
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
    """Dummy Simulator flag. Default to fault, using QuantumClifford for simulation"""
    dummy::Bool
end
##
"""TODO docstring"""
abstract type QuantumRuntime end

"""TODO docstring -- all measurements return `nothing` and classically-trackable states are set as if result was `false`."""
struct MockRuntime <: QuantumRuntime end
##
function _result_type_str(t)
    t == ClassicalDetermRes() && return "ClassicalDeterministic"
    t == ClassicalRandomRes() && return "ClassicalRandom"
    t == QuantumRes()         && return "Quantum"
    return string(t)
end

_bool_str(::Nothing) = "nothing"
_bool_str(b::Bool) = string(b)

function _magic_pauli_str(p::PauliOperator, magic_qubits::Vector{Int})
    phase_char = p.phase[] in (0x00, 0x01) ? '+' : '-'
    chars = map(magic_qubits) do i
        x, z = p[i]
        x && z ? 'Y' : x ? 'X' : z ? 'Z' : '_'
    end
    return string(phase_char, String(chars))
end

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
    if !isdefined(ms, :measurement_results)
        println(io, "  Measurements: undefined")
        println(io, "  Quantum Measurement Results: undefined")
    else
        n = length(ms.measurement_results)
        println(io, "  Measurements ($n):")
        for i in 1:n
            if !isassigned(ms.measurement_results, i)
                println(io, "    [$i] undefined")
                continue
            end
            m = ms.measurement_results[i]
            println(io, "    [$i] ", m.pauli,
                        "  →  ", _bool_str(m.result),
                        "  (", _result_type_str(m.result_type), ")")
        end
        quantum = filter(i -> isassigned(ms.measurement_results, i) &&
                              ms.measurement_results[i].result_type == QuantumRes(),
                         1:n)
        println(io, "  Quantum Measurement Results ($(length(quantum))):")
        for (j, i) in enumerate(quantum)
            m = ms.measurement_results[i]
            println(io, "    [$j] ", _magic_pauli_str(m.pauli, ms.magic_qubits),
                        "  →  ", _bool_str(m.result))
        end
    end
    print(io, "  Stabilizer Group:\n")
    show(io, ms.StabilizerGroup)
end
