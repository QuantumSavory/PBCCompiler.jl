@testitem "check_commutation" tags=[:check_commutation] begin

using PBCCompiler
using PBCCompiler: Circuit, CircuitOp, Measurement, ExpHalfPiPauli, ExpQuatPiPauli, ExpEighPiPauli, PauliConditional, BitConditional, affectedqubits
using Test
using PBCCompiler: check_commutation
using QuantumClifford: @P_str, comm
@testset "Test unordered input" begin
    op1=ExpQuatPiPauli(P"XY", [1, 3])
    op2=ExpQuatPiPauli(P"ZXY", [3, 1, 2])

    t_1=comm(op1.pauli,op2.pauli)
    @test t_1 == 0x00

    t_2=check_commutation(op1, op2)
    @test t_2 == 0x01

end

@testset "Test non-overlapping input" begin
    op1=ExpQuatPiPauli(P"X", [1])
    op2=ExpQuatPiPauli(P"Z", [2])

    t_1=comm(op1.pauli,op2.pauli)
    @test t_1 == 0x01

    t_2=check_commutation(op1, op2)
    @test t_2 == 0x00

end

@testset "Test partially overlapping input" begin
    op1=ExpQuatPiPauli(P"XX", [1, 3])
    op2=ExpQuatPiPauli(P"ZY", [3, 4])

    t_1=comm(op1.pauli,op2.pauli)
    @test t_1 == 0x00

    t_2=check_commutation(op1, op2)
    @test t_2 == 0x01

end

@testset "Test Pauli Product Rotation/Measurement input" begin
    op1=ExpHalfPiPauli(P"X", [1])
    op2=ExpQuatPiPauli(P"Z", [1])
    op3=ExpEighPiPauli(P"Y", [1])
    M_Z=CircuitOp.Measurement(P"Z", 1, [1])

    t_1=check_commutation(op1,op2)
    @test t_1 == 0x01

    t_2=check_commutation(op1, op2)
    @test t_2 == 0x01

    t_3=check_commutation(op1,op3)
    @test t_3 == 0x01

    t_4=check_commutation(op1,M_Z)
    @test t_4 == 0x01

    t_5=check_commutation(op2,M_Z)
    @test t_5 == 0x00

    t_6=check_commutation(op3,M_Z)
    @test t_6 == 0x01
end

@testset "Test invalid input" begin
    CNOT=PauliConditional(P"Z", [1], P"X", [2])
    Con_Z=BitConditional(ExpHalfPiPauli(P"Z", [1]), 1)
    nonclifford_op=CircuitOp.ExpEighPiPauli(P"Z", [2])
    M_Z=CircuitOp.Measurement(P"Z", 1, [2])

    t_1=check_commutation(CNOT,nonclifford_op)
    @test t_1 === nothing

    t_2=check_commutation(CNOT,M_Z)
    @test t_2 === nothing

    t_3=check_commutation(Con_Z,nonclifford_op)
    @test t_3 === nothing

    t_4=check_commutation(Con_Z,M_Z)
    @test t_4 === nothing
end

end
