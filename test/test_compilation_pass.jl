@testitem "Preprocess" tags=[:preprocess] begin

using PBCCompiler
using PBCCompiler: Circuit, CircuitOp, Pauli, Measurement, ExpHalfPiPauli, ExpQuatPiPauli,ExpEighPiPauli, PauliConditional, BitConditional, preprocess_circuit, run, SimRuntime, DummyRuntime, group_nonclifford
using PBCCompiler.MeasurementResult
using .MeasurementResult: ClassicalDetermRes, ClassicalRandomRes, QuantumRes
using QuantumClifford: @P_str, @S_str
using Moshi.Derive: @derive
using Moshi.Match: isa_variant

@derive CircuitOp[Eq, Show]

@testset "Basic Preprocess" begin
    # Test empty circuit
    circuit = Circuit()
    preprocess_circuit(circuit)
    @test isempty(circuit)

    # Test single-element circuit (no pairs to traverse)
    circuit = Circuit([Pauli(P"X", [1])])
    preprocess_circuit(circuit)
    @test length(circuit) == 1
end

@testset "Preprocess Correctness" begin
    circuit = Circuit([
    ExpQuatPiPauli(P"Z", [1]),
    ExpQuatPiPauli(P"X", [1]),
    ExpQuatPiPauli(P"Z", [1]),
    PauliConditional(P"Z", [1], P"X", [2]),
    ExpEighPiPauli(P"Z", [2]),
    Measurement(P"Z", 1, [1]),
    Measurement(P"Z", 2, [2])
    ])

    preprocess_circuit(circuit)

    @test circuit[1] == Measurement(P"XZZ", 3, [1, 2, 3])
    @test circuit[2] == Measurement(P"X", 4, [3])
    @test circuit[3] == BitConditional((ExpQuatPiPauli(P"XZ", [1, 2])), 3)
    @test circuit[4] == BitConditional((ExpHalfPiPauli(P"XZ", [1, 2])), 4)
    @test circuit[5] == Measurement(P"X_", 1, [1, 2])
    @test circuit[6] == Measurement(P"XZ", 2, [1, 2])
end


@testset "group_nonclifford with a non-Clifford at index 1" begin
    e1 = ExpEighPiPauli(P"Z", [1])
    c  = ExpQuatPiPauli(P"X", [1])
    e2 = ExpEighPiPauli(P"Z", [1])
    circuit = Circuit([e1, c, e2])
    group_nonclifford(circuit)
    # e1 has nothing to its left and must stay put; e2 commutes past c (conjugated)
    @test circuit[1] == e1
    @test isa_variant(circuit[2], CircuitOp.ExpEighPiPauli)
    @test circuit[3] == c
end

@testset "inverse rotations cancel instead of leaving a placeholder" begin
    merge_ops = PBCCompiler.merge_ops
    # pi/8 followed by -pi/8 about the same axis is the identity
    circuit = Circuit([ExpEighPiPauli(P"Z", [1]), ExpEighPiPauli(-P"Z", [1])])
    merge_ops(circuit)
    @test isempty(circuit)
    # two pi/2 rotations about the same axis are a global phase
    circuit = Circuit([ExpHalfPiPauli(P"Z", [1]), ExpHalfPiPauli(P"Z", [1])])
    merge_ops(circuit)
    @test isempty(circuit)
    # same-sign pi/8 pair still merges into a pi/4 rotation
    circuit = Circuit([ExpEighPiPauli(P"Z", [1]), ExpEighPiPauli(P"Z", [1])])
    merge_ops(circuit)
    @test length(circuit) == 1
    @test isa_variant(circuit[1], CircuitOp.ExpQuatPiPauli)
end

@testset "SimRuntime Correctness" begin
    circuit = Circuit([
    PauliConditional(P"X", [1], P"Z", [2]),
    ExpHalfPiPauli(P"YZ", [1, 2]),
    ExpEighPiPauli(P"Z", [2]),
    Measurement(P"Z", 1, [1]),
    Measurement(P"Z", 2, [2])
    ])

    real_result=run(circuit, SimRuntime())
    meas_list=real_result.measurement_results
    stab=real_result.stabilizer_group

    @test isa_variant(meas_list[1], QuantumRes)
    @test isa_variant(meas_list[2], ClassicalRandomRes)
    @test isa_variant(meas_list[3], ClassicalDetermRes)
    @test isa_variant(meas_list[4], ClassicalDetermRes)
    @test stab == S"+Z__
                    +_Z_
                    +_ZZ"
end

@testset "DummyRuntime Correctness" begin
    circuit = Circuit([
    PauliConditional(P"X", [1], P"Z", [2]),
    ExpHalfPiPauli(P"YZ", [1, 2]),
    ExpEighPiPauli(P"Z", [2]),
    Measurement(P"Z", 1, [1]),
    Measurement(P"Z", 2, [2])
    ])

    real_result=run(circuit, DummyRuntime())
    meas_list=real_result.measurement_results
    stab=real_result.stabilizer_group

    @test isa_variant(meas_list[1], QuantumRes)
    @test isa_variant(meas_list[2], ClassicalRandomRes)
    @test isa_variant(meas_list[3], ClassicalDetermRes)
    @test isa_variant(meas_list[4], ClassicalDetermRes)
    @test stab == S"+Z__
                    +_Z_
                    +_ZZ"
end

end
