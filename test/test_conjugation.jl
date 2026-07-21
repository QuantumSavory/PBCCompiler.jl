@testitem "check_conjugation" tags=[:check_conjugation] begin

using PBCCompiler
using PBCCompiler: Circuit, CircuitOp, Measurement, ExpHalfPiPauli, ExpQuatPiPauli, ExpEighPiPauli, PauliConditional, BitConditional, affectedqubits
using Test
using PBCCompiler: conjugate_noncliff, conjugate_measurement
using QuantumClifford: @P_str
using Moshi.Derive: @derive

@derive CircuitOp[Eq, Show]

@testset "Test unordered input" begin
    op1=CircuitOp.ExpQuatPiPauli(P"ZXY", [3, 1, 2])
    op2=CircuitOp.ExpEighPiPauli(P"XY", [1,3])
    M_Z=CircuitOp.Measurement(P"Z", 1, [2])

    conjugated_noncliff=CircuitOp.ExpEighPiPauli(P"_YX", [1, 2, 3])
    conjugated_measurement=CircuitOp.Measurement(P"-XXZ", 1, [1, 2, 3])

    t_1=conjugate_noncliff(op1,op2)
    @test t_1 == (conjugated_noncliff, op1)

    t_2=conjugate_measurement(op1,M_Z)
    @test t_2 == (conjugated_measurement, op1)
end

@testset "Test non-overlapping input" begin
    op1=CircuitOp.ExpQuatPiPauli(P"X", [1])
    op2=CircuitOp.ExpEighPiPauli(P"Z", [2])
    M_Z=CircuitOp.Measurement(P"Z", 1, [2])

    conjugated_noncliff=CircuitOp.ExpEighPiPauli(P"_Z", [1, 2])
    conjugated_measurement=CircuitOp.Measurement(P"_Z", 1, [1, 2])

    t_1=conjugate_noncliff(op1,op2)
    @test t_1 == (conjugated_noncliff, op1)

    t_2=conjugate_measurement(op1,M_Z)
    @test t_2 == (conjugated_measurement, op1)
end

@testset "Test on CircuitOp.ExpHalfPiPauli" begin
    op1 = CircuitOp.ExpHalfPiPauli(P"YX", [1, 2])
    op2=CircuitOp.ExpEighPiPauli(P"XY", [1,3])
    M_Z=CircuitOp.Measurement(P"Z", 1, [2])

    conjugated_noncliff=ExpEighPiPauli(P"-X_Y", [1, 2, 3])
    conjugated_measurement=CircuitOp.Measurement(P"-_Z", 1, [1, 2])

    t_1=conjugate_noncliff(op1,op2)
    @test t_1 == (conjugated_noncliff, op1)

    t_2=conjugate_measurement(op1,M_Z)
    @test t_2 == (conjugated_measurement, op1)
end

@testset "Test on unexpected inputs" begin
    CNOT=PauliConditional(P"Z", [1], P"X", [2])
    Con_Z=BitConditional(ExpHalfPiPauli(P"Z", [1]), 1)
    clifford_op=CircuitOp.ExpQuatPiPauli(P"X", [1])
    nonclifford_op=CircuitOp.ExpEighPiPauli(P"Z", [2])
    M_Z=CircuitOp.Measurement(P"Z", 1, [2])

    t_1=conjugate_noncliff(CNOT,nonclifford_op)
    @test t_1 === nothing

    t_2=conjugate_measurement(CNOT,M_Z)
    @test t_2 === nothing

    t_3=conjugate_noncliff(Con_Z,nonclifford_op)
    @test t_3 === nothing

    t_4=conjugate_measurement(Con_Z,M_Z)
    @test t_4 === nothing

    t_5=conjugate_noncliff(M_Z,nonclifford_op)
    @test t_5 === nothing

    t_6=conjugate_measurement(nonclifford_op,M_Z)
    @test t_6 === nothing

    t_7=conjugate_noncliff(clifford_op, M_Z)
    @test t_6 === nothing

    t_8=conjugate_measurement(clifford_op, nonclifford_op)
    @test t_8 === nothing

    t_9=conjugate_noncliff(clifford_op, CNOT)
    @test t_9 === nothing

    t_10=conjugate_noncliff(clifford_op, Con_Z)
    @test t_10 === nothing

    t_11=conjugate_noncliff(clifford_op, clifford_op)
    @test t_11 === nothing

    t_12=conjugate_measurement(clifford_op, CNOT)
    @test t_12 === nothing

    t_13=conjugate_measurement(clifford_op, Con_Z)
    @test t_13 === nothing

    t_14=conjugate_measurement(clifford_op, clifford_op)
    @test t_14 === nothing
end

end
