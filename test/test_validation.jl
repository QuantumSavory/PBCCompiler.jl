@testitem "Input validation regressions" tags=[:bugfixes] begin

using PBCCompiler
using PBCCompiler: Circuit, CircuitOp, Pauli, Measurement, ExpHalfPiPauli, ExpQuatPiPauli,
    ExpEighPiPauli, PauliConditional, BitConditional, traversal, preprocess_circuit,
    validate_CircuitOp, PauliQubitMismatchError, find_variant_indices, group_nonclifford,
    quantum_measurement, resolve_conditionals,
    run, CompilerState, MeasurementResult,
    SimRuntime, DummyRuntime
using .MeasurementResult: ClassicalDetermRes
using QuantumClifford: @P_str, @S_str
using Moshi.Derive: @derive
using Moshi.Match: isa_variant

@derive CircuitOp[Eq, Show]

@testset "validate_CircuitOp on PauliConditional with empty qubits" begin
    op = PauliConditional(P"X", Int[], P"Z", [2])
    @test_throws PauliQubitMismatchError validate_CircuitOp(op)
end

@testset "preprocess_circuit on a measurement-free circuit" begin
    circuit = Circuit([ExpQuatPiPauli(P"X", [1]), ExpHalfPiPauli(P"Z", [1])])
    preprocess_circuit(circuit)
    @test length(circuit) == 2
end

@testset "gadget classical bits never collide with user bits" begin
    # User bit index (2) exceeds the qubit count (1); gadget bits must go above it
    circuit = Circuit([ExpEighPiPauli(P"Z", [1]), Measurement(P"Z", 2, [1])])
    preprocess_circuit(circuit)
    bits = [circuit[i].bit for i in find_variant_indices(circuit, Measurement)]
    @test allunique(bits)
    @test 2 in bits
end

@testset "imaginary-phase Paulis are rejected" begin
    @test_throws ArgumentError validate_CircuitOp(ExpQuatPiPauli(im * P"X", [1]))
    @test_throws ArgumentError validate_CircuitOp(Measurement(-im * P"Z", 1, [1]))
    # Real phases remain valid
    validate_CircuitOp(ExpQuatPiPauli(-P"X", [1]))
    @test true
end

@testset "random_test_circuit only generates Hermitian Paulis" begin
    circuit = PBCCompiler.random_test_circuit(50, 3)
    for op in circuit
        if !isa_variant(op, CircuitOp.PauliConditional)
            @test iseven(op.pauli.phase[])
        end
    end
end

@testset "input validation rejects malformed operations" begin
    validate_circuit = PBCCompiler.validate_circuit
    # PrepMagic is not supported by the pipeline
    @test_throws ArgumentError validate_CircuitOp(PBCCompiler.PrepMagic(2, [1]))
    # Overlapping control/target registers in PauliConditional
    @test_throws ArgumentError validate_CircuitOp(PauliConditional(P"Z", [1], P"X", [1]))
    # Non-positive qubit indices
    @test_throws ArgumentError validate_CircuitOp(Measurement(P"Z", 1, [0]))
    @test_throws ArgumentError validate_CircuitOp(Measurement(P"Z", 1, [-2]))
    # Non-positive classical bit indices
    @test_throws ArgumentError validate_CircuitOp(Measurement(P"Z", 0, [1]))
    @test_throws ArgumentError validate_CircuitOp(BitConditional(ExpHalfPiPauli(P"X", [1]), 0))
    # Duplicate measurement bits would silently drop a measurement downstream
    @test_throws ArgumentError validate_circuit(Circuit([
        Measurement(P"Z", 1, [1]), Measurement(P"X", 1, [1])]))
    # BitConditional controlled by a bit no measurement writes
    @test_throws ArgumentError validate_circuit(Circuit([
        BitConditional(ExpHalfPiPauli(P"X", [1]), 7), Measurement(P"Z", 1, [1])]))
    # A well-formed circuit still validates
    validate_circuit(Circuit([
        BitConditional(ExpHalfPiPauli(P"X", [1]), 1),
        PauliConditional(P"Z", [1], P"X", [2]),
        Measurement(P"Z", 1, [1]), Measurement(P"Z", 2, [2])]))
    @test true
    # ... and run() surfaces the validation error
    @test_throws ArgumentError PBCCompiler.run(
        Circuit([Measurement(P"Z", 1, [1]), Measurement(P"X", 1, [1])]), DummyRuntime())
end

@testset "single-op circuits go through the full pipeline" begin
    circuit = Circuit([ExpEighPiPauli(P"Z", [1])])
    preprocess_circuit(circuit)
    @test isempty(find_variant_indices(circuit, ExpEighPiPauli))
    @test !isempty(find_variant_indices(circuit, Measurement))

    circuit = Circuit([PauliConditional(P"Z", [1], P"X", [2])])
    preprocess_circuit(circuit)
    @test isempty(find_variant_indices(circuit, PauliConditional))
end

end
