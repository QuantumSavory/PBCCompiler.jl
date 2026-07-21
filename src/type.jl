using QuantumClifford: PauliOperator, @P_str, Stabilizer, GeneralizedStabilizer
using Moshi.Data: @data, variant_name
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
@data MeasurementResult begin
    """Denoting measurement results that classically determined by a coin flip"""
    struct ClassicalDetermRes
        """Corresponding Pauli String of Measurement"""
        pauli::PauliOperator
        """Single bit measurement result in boolean"""
        result::Bool
    end
    """Denoting measurement results that are classically determined by stored eigenvalues of stabilizers"""
    struct ClassicalRandomRes
        """Corresponding Pauli String of Measurement"""
        pauli::PauliOperator
        """Single bit measurement result in boolean"""
        result::Bool
    end
    """Denoting measurement results that require performing actual quantum measurement"""
    struct QuantumRes
        """Corresponding Pauli String of Measurement"""
        pauli::PauliOperator
        """Single bit measurement result in boolean"""
        result::Bool
    end
end

using .MeasurementResult: ClassicalDetermRes, ClassicalRandomRes, QuantumRes

@derive MeasurementResult[Hash, Eq, Show]
##
abstract type AbstractRuntime end

struct SimRuntime <: AbstractRuntime
    """GeneralizedStabilizer object holding current quantum state within quantum computer"""
    quantum_memory::Union{GeneralizedStabilizer, Nothing}
end

SimRuntime() = SimRuntime(nothing)

struct DummyRuntime <: AbstractRuntime
    """Weight vector describes sampling probability between +1 and -1 measurement results"""
    p1_outcome_probs::Float16
end

DummyRuntime() = DummyRuntime(0.5)
##
"""Struct that contains information describing current compiler state"""
Base.@kwdef struct CompilerState
    """Vector that holds all MeasurementResult in temporal order -- first measurement result is the first CircuitOp.Measurement being measured"""
    measurement_results::Vector{MeasurementResult.Type}
    """
    Stabilizer object that describes current quantum state
    It has n columns where n is the number of total qubits (magic and stabilizer state qubits)
    The tableau is not square (full-rank) before compilation is finished
    """
    stabilizer_group::Stabilizer
    """Result of Measurement(..., bit, ...) is stored in classical_register[bit]"""
    classical_register::Vector{Union{Nothing,Bool}}
    """Contain current circuit object"""
    circuit::Circuit
    """Denote the Pauli Product Measurement that is being processed"""
    instruction_pointer::Int
    """TODO docstring"""
    runtime::AbstractRuntime
end
##
function _result_type_str(t)
    t == :ClassicalDetermRes && return "ClassicalDeterministic"
    t == :ClassicalRandomRes && return "ClassicalRandom"
    t == :QuantumRes         && return "Quantum"
    return string(t)
end

_bool_str(::Nothing) = "nothing"
_bool_str(b::Bool) = string(b)

"""
    show(io::IO, result::CompilerState)

Pretty-print all debug-relevant fields of a `CompilerState`.

# Arguments
- `io`: output stream
- `result`: compiler state to display

# Returns
Nothing; writes to `io`.
"""
function Base.show(io::IO, result::CompilerState)
    println(io, "CompilerState [debug]")
    println(io, "  Instruction Pointer: ", result.instruction_pointer)
    n = length(result.measurement_results)
    println(io, "  Measurements ($n):")
    for i in 1:n
        if !isassigned(result.measurement_results, i)
            println(io, "    [$i] undefined")
            continue
        end
        m = result.measurement_results[i]
        println(io, "    [$i] ", m.pauli,
                    "  →  ", _bool_str(m.result),
                    "  (", _result_type_str(variant_name(m)), ")")
    end
    reg = join(map(_bool_str, result.classical_register), ", ")
    println(io, "  Classical Register: [", reg, "]")
    #println(io, "  Runtime: ", variant_name(result.runtime))
    print(io, "  Stabilizer Group:\n")
    show(io, result.stabilizer_group)
end
