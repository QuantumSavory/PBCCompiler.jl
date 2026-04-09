@testitem "check_conjugation" tags=[:check_conjugation] begin

using PBCCompiler
using PBCCompiler: Circuit, CircuitOp, Measurement, ExpHalfPiPauli, ExpQuatPiPauli, ExpEighPiPauli, PauliConditional, BitConditional, affectedqubits
using Test
using PBCCompiler: conjugate
using QuantumClifford: @P_str
using Moshi.Derive: @derive

@derive CircuitOp[Eq, Show]

@testset "Test unordered input" begin
    op1=ExpQuatPiPauli(P"XY", [1, 3])
    op2=ExpQuatPiPauli(P"ZXY", [3, 1, 2])
    conjugated_op=ExpQuatPiPauli(P"-_YX", [1, 2, 3])

    t_1=conjugate(op1,op2)
    @test t_1 == (conjugated_op, op1)

end

@testset "Test non-overlapping input" begin
    op1=ExpQuatPiPauli(P"X", [1])
    op2=ExpQuatPiPauli(P"Z", [2])
    conjugated_op=ExpQuatPiPauli(P"_Z", [1, 2])

    t_1=conjugate(op1,op2)
    @test t_1 == (conjugated_op, op1)

end

@testset "Test on single qubit CircuitOps" begin
    op1=ExpQuatPiPauli(P"X", [1])
    op2=ExpEighPiPauli(P"Z", [1])
    op3=ExpHalfPiPauli(P"Y", [1])
    conjugated_op_1=ExpEighPiPauli(P"Y", [1])
    conjugated_op_2=ExpHalfPiPauli(P"-Z", [1])
    conjugated_op_3=ExpQuatPiPauli(P"-X", [1])

    t_1=conjugate(op1,op2)
    @test t_1 == (conjugated_op_1, op1)
    t_2=conjugate(op1,op3)
    @test t_2 == (conjugated_op_2, op1)
    t_3=conjugate(op3,op1)
    @test t_3 == (conjugated_op_3, op3)

end

@testset "Test on PauliConditionals" begin
    op1=ExpQuatPiPauli(P"X", [1])
    op2=ExpQuatPiPauli(P"Z", [2])
    CNOT=PauliConditional(P"Z", [1], P"X", [2])
    conjugated_op_1=ExpQuatPiPauli(P"XX", [1, 2])
    conjugated_op_2=ExpQuatPiPauli(P"ZZ", [1, 2])

    t_1=conjugate(CNOT,op1)
    @test t_1 == (conjugated_op_1, CNOT)

    T_2=conjugate(CNOT,op2)
    @test T_2 == (conjugated_op_2, CNOT)

end

@testset "Test on BitConditionals" begin
    op1=ExpQuatPiPauli(P"X", [1])
    Con_Z=BitConditional(ExpHalfPiPauli(P"Z", [1]), 1)

    t_1=conjugate(Con_Z, op1)
    @test t_1 === nothing

end

@testset "Test on Measurements" begin
    op1=ExpQuatPiPauli(P"X", [2])
    op2=ExpHalfPiPauli(P"X", [2])
    CNOT=PauliConditional(P"Z", [1], P"X", [2])
    M_Z=Measurement(P"Z", 1, [2])
    conjugated_op_1=Measurement(P"_Y", 1, [1, 2])
    conjugated_op_2=Measurement(P"-_Z", 1, [1, 2])
    conjugated_op_3=Measurement(P"ZZ", 1, [1, 2])

    t_1=conjugate(M_Z, op1)
    @test t_1 === nothing

    t_2=conjugate(op1, M_Z)
    @test t_2 == (conjugated_op_1, op1)

    t_3=conjugate(op2, M_Z)
    @test t_3 == (conjugated_op_2, op2)

    t_4=conjugate(CNOT, M_Z)
    @test t_4 == (conjugated_op_3, CNOT)
end

@testset "Test on BitConditional" begin
    op1=ExpQuatPiPauli(P"X", [1])
    Con_Z=BitConditional(ExpHalfPiPauli(P"Z", [1]), 1)

    t_1=conjugate(Con_Z, op1)
    @test t_1 === nothing
end

@testset "Test on Invalid Inputs" begin
    op1=ExpQuatPiPauli(P"X", [1])
    measZ=Measurement(P"Z", 1, [1])
    measX=Measurement(P"X", 1, [1])

    t_1=conjugate(measZ, op1)
    @test t_1 === nothing

    t_2=conjugate(measX, measZ)
    @test t_2 === nothing
end

end
