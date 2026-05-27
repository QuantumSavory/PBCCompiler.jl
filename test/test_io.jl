@testitem "io" tags=[:io] begin

# test_parse.jl — unit tests for parse_input
using JLD2
using PBCCompiler: Circuit, CircuitOp, Measurement, ExpHalfPiPauli, ExpQuatPiPauli, ExpEighPiPauli, PauliConditional
using PBCCompiler: MeasurementResultType, MeasurementResult, classical_deterministic_result, classical_random_result, quantum_result, MemoryState, ComputerState
using .MeasurementResultType: ClassicalDetermRes, ClassicalRandomRes, QuantumRes
using Moshi.Data: isa_variant
using QuantumClifford: @P_str, Stabilizer
using PBCCompiler: parse_input, save
"""
    with_qasm(f, gates)

Write a minimal OpenQASM 2.0 file containing `gates` to a temp path,
call `f(path)`, then delete the file. The header (`OPENQASM 2.0`,
`include`, `qreg q[3]`, `creg c[3]`) is prepended automatically.
"""
function with_qasm(f::Function, gates::String)
    path = tempname() * ".qasm"
    write(path, """OPENQASM 2.0;
include "qelib1.inc";
qreg q[3];
creg c[3];
$gates
""")
    try
        f(path)
    finally
        rm(path; force=true)
    end
end

const FIXTURES = joinpath(@__DIR__, "fixtures")

@testset "Header lines produce no ops" begin
    with_qasm("") do path
        @test isempty(parse_input(path))
    end
end

@testset "Hadamard gate (h)" begin
    with_qasm("h q[0];") do path
        c = parse_input(path)
        # H → three consecutive ExpQuatPiPauli: Z, X, Z
        @test length(c) == 3
        @test all(isa_variant(op, CircuitOp.ExpQuatPiPauli) for op in c)
        @test c[1].pauli == P"Z" && c[1].qubits == [1]
        @test c[2].pauli == P"X" && c[2].qubits == [1]
        @test c[3].pauli == P"Z" && c[3].qubits == [1]
    end
end

@testset "Phase gate (s)" begin
    with_qasm("s q[1];") do path
        c = parse_input(path)
        @test length(c) == 1
        @test isa_variant(c[1], CircuitOp.ExpQuatPiPauli)
        @test c[1].pauli == P"Z" && c[1].qubits == [2]
    end
end

@testset "Phase-dagger gate (sdg)" begin
    with_qasm("sdg q[0];") do path
        c = parse_input(path)
        @test length(c) == 1
        @test isa_variant(c[1], CircuitOp.ExpQuatPiPauli)
        @test c[1].pauli == -P"Z" && c[1].qubits == [1]
    end
end

@testset "T gate (t)" begin
    with_qasm("t q[2];") do path
        c = parse_input(path)
        @test length(c) == 1
        @test isa_variant(c[1], CircuitOp.ExpEighPiPauli)
        @test c[1].pauli == P"Z" && c[1].qubits == [3]
    end
end

@testset "T-dagger gate (tdg)" begin
    with_qasm("tdg q[1];") do path
        c = parse_input(path)
        @test length(c) == 1
        @test isa_variant(c[1], CircuitOp.ExpEighPiPauli)
        @test c[1].pauli == -P"Z" && c[1].qubits == [2]
    end
end

@testset "Pauli X gate (x)" begin
    with_qasm("x q[0];") do path
        c = parse_input(path)
        @test length(c) == 1
        @test isa_variant(c[1], CircuitOp.ExpHalfPiPauli)
        @test c[1].pauli == P"X" && c[1].qubits == [1]
    end
end

@testset "Pauli Y gate (y)" begin
    with_qasm("y q[0];") do path
        c = parse_input(path)
        @test length(c) == 1
        @test isa_variant(c[1], CircuitOp.ExpHalfPiPauli)
        @test c[1].pauli == P"Y" && c[1].qubits == [1]
    end
end

@testset "Pauli Z gate (z)" begin
    with_qasm("z q[0];") do path
        c = parse_input(path)
        @test length(c) == 1
        @test isa_variant(c[1], CircuitOp.ExpHalfPiPauli)
        @test c[1].pauli == P"Z" && c[1].qubits == [1]
    end
end

@testset "CNOT gate (cx)" begin
    with_qasm("cx q[0],q[1];") do path
        c = parse_input(path)
        @test length(c) == 1
        @test isa_variant(c[1], CircuitOp.PauliConditional)
        @test c[1].control_pauli  == P"Z"  && c[1].control_qubits == [1]
        @test c[1].target_pauli   == P"X"  && c[1].target_qubits  == [2]
    end
end

@testset "Measurement" begin
    with_qasm("measure q[2] -> c[1];") do path
        c = parse_input(path)
        @test length(c) == 1
        @test isa_variant(c[1], CircuitOp.Measurement)
        @test c[1].pauli  == P"Z"
        @test c[1].qubits == [3]
        @test c[1].bit    == 2
    end
end

@testset "Gate sequence ordering is preserved" begin
    with_qasm("s q[0];\nt q[0];\nsdg q[0];") do path
        c = parse_input(path)
        @test length(c) == 3
        @test isa_variant(c[1], CircuitOp.ExpQuatPiPauli) && c[1].pauli == P"Z"   # s
        @test isa_variant(c[2], CircuitOp.ExpEighPiPauli) && c[2].pauli == P"Z"   # t
        @test isa_variant(c[3], CircuitOp.ExpQuatPiPauli) && c[3].pauli == -P"Z"  # sdg
    end
end

@testset "Mixed multi-qubit sequence" begin
    with_qasm("h q[0];\ncx q[0],q[1];\nmeasure q[0] -> c[0];") do path
        c = parse_input(path)
        # h → 3 ops, cx → 1 op, measure → 1 op
        @test length(c) == 5
        @test all(isa_variant(c[i], CircuitOp.ExpQuatPiPauli) for i in 1:3)
        @test isa_variant(c[4], CircuitOp.PauliConditional)
        @test isa_variant(c[5], CircuitOp.Measurement)
    end
end

@testset "Sample input file (sample_input.qasm)" begin
    c = parse_input(joinpath(FIXTURES,"sample_input.qasm"))
    cx_ops      = filter(op -> isa_variant(op, CircuitOp.PauliConditional), c)
    measure_ops = filter(op -> isa_variant(op, CircuitOp.Measurement),      c)
    @test length(cx_ops)      == 3
    @test length(measure_ops) == 2
    # Measurements are in Z basis on qubits 0 and 1
    @test all(op.pauli == P"Z" for op in measure_ops)
    @test measure_ops[1].qubits == [1] && measure_ops[1].bit == 1
    @test measure_ops[2].qubits == [2] && measure_ops[2].bit == 2
end

##
# ---------------------------------------------------------------------------
# Helper: construct a minimal ComputerState for testing
# ---------------------------------------------------------------------------
function _make_state(;
    num_gadgets = 3,
    meas_results   = MeasurementResult[
                         classical_deterministic_result(P"XZ", true),
                         classical_random_result(P"ZX", false),
                         quantum_result(P"YI", nothing),
                     ],
    stab           = Stabilizer([P"XX", P"ZZ"]),
    quantum_memory = nothing,
    classical_reg  = Union{Nothing,Bool}[true, false, nothing],
)
    ms = MemoryState(meas_results, stab, quantum_memory, classical_reg)
    return ComputerState(Circuit(),num_gadgets, 1, ms)
end

# ---------------------------------------------------------------------------

# Tests that `save` creates a file at the exact path supplied.
# Verifies the basic contract that calling save produces a file on disk.
@testset "save creates file at specified path" begin
    path = tempname() * ".jld2"
    save(_make_state(), path)
    @test isfile(path)
    rm(path)
end

# Tests that the saved file contains exactly the four expected top-level keys
# (`pauli_qubits`, `magic_qubits`, `measurement_results`, `stabilizer_group`)
# and that `classical_register` — the fifth field of MemoryState — is absent.
@testset "save writes correct keys" begin
    path = tempname() * ".jld2"
    save(_make_state(), path)
    data = JLD2.load(path)
    @test !haskey(data, "num_gadgets")
    @test haskey(data, "measurement_results")
    @test haskey(data, "stabilizer_group")
    @test !haskey(data, "classical_register")
    rm(path)
end

# Tests that each MeasurementResult (Pauli string, boolean result, result type)
# round-trips faithfully, covering all three result-type variants and a `nothing`
# result value.
@testset "save round-trips measurement_results" begin
    path = tempname() * ".jld2"
    save(_make_state(), path)
    data   = JLD2.load(path)
    loaded = data["measurement_results"]

    @test length(loaded) == 3
    @test loaded[1].pauli  == P"XZ"
    @test loaded[1].result == true
    @test loaded[1].result_type == ClassicalDetermRes()

    @test loaded[2].pauli  == P"ZX"
    @test loaded[2].result == false
    @test loaded[2].result_type == ClassicalRandomRes()

    @test loaded[3].pauli  == P"YI"
    @test loaded[3].result === nothing
    @test loaded[3].result_type == QuantumRes()
    rm(path)
end

# Tests that the stabilizer_group round-trips through the JLD2 file,
# checking both the number of generators and their individual Pauli strings.
@testset "save round-trips stabilizer_group" begin
    stab = Stabilizer([P"XX", P"ZZ"])
    path = tempname() * ".jld2"
    save(_make_state(stab=stab), path)
    data   = JLD2.load(path)
    loaded = data["stabilizer_group"]

    @test length(loaded) == 2
    @test loaded[1] == P"XX"
    @test loaded[2] == P"ZZ"
    rm(path)
end

end
