using BenchmarkTools
using PBCCompiler
using PBCCompiler: Circuit, CircuitOp, Pauli, Measurement, ExpHalfPiPauli, traversal
using QuantumClifford: @P_str
using Moshi.Data: isa_variant

const SUITE = BenchmarkGroup()

# Helper function to create a circuit with n Pauli gates
function make_pauli_circuit(n::Int)
    paulis = [P"X", P"Y", P"Z", P"I"]
    ops = [Pauli(paulis[mod1(i, 4)], [1]) for i in 1:n]
    return Circuit(ops)
end

# Helper function to create a mixed circuit with different gate types
function make_mixed_circuit(n::Int)
    paulis = [P"X", P"Y", P"Z"]
    ops = CircuitOp.Type[]
    for i in 1:n
        p = paulis[mod1(i, 3)]
        if i % 4 == 0
            push!(ops, Measurement(p, i, [1]))
        elseif i % 4 == 1
            push!(ops, Pauli(p, [1]))
        elseif i % 4 == 2
            push!(ops, ExpHalfPiPauli(p, [1]))
        else
            push!(ops, Pauli(p, [1, 2]))
        end
    end
    return Circuit(ops)
end

# Transformation functions for benchmarks
swap_transform(op1, op2) = (op2, op1)
noop_transform(op1, op2) = nothing
function combine_paulis(op1, op2)
    if isa_variant(op1, CircuitOp.Pauli) && isa_variant(op2, CircuitOp.Pauli)
        return Pauli(P"X", [1])
    end
    return nothing
end

# Traversal benchmarks
SUITE["traversal"] = BenchmarkGroup(["traversal"])

# Swap traversal - moves operations around without changing circuit length
SUITE["traversal"]["swap"] = BenchmarkGroup(["swap"])
SUITE["traversal"]["swap"]["10"] = @benchmarkable traversal(c, swap_transform) setup=(c=make_pauli_circuit(10)) evals=1
SUITE["traversal"]["swap"]["100"] = @benchmarkable traversal(c, swap_transform) setup=(c=make_pauli_circuit(100)) evals=1
SUITE["traversal"]["swap"]["1000"] = @benchmarkable traversal(c, swap_transform) setup=(c=make_pauli_circuit(1000)) evals=1

# No-op traversal - visits all pairs but makes no changes
SUITE["traversal"]["noop"] = BenchmarkGroup(["noop"])
SUITE["traversal"]["noop"]["10"] = @benchmarkable traversal(c, noop_transform) setup=(c=make_pauli_circuit(10)) evals=1
SUITE["traversal"]["noop"]["100"] = @benchmarkable traversal(c, noop_transform) setup=(c=make_pauli_circuit(100)) evals=1
SUITE["traversal"]["noop"]["1000"] = @benchmarkable traversal(c, noop_transform) setup=(c=make_pauli_circuit(1000)) evals=1

# Combine traversal - reduces circuit by combining adjacent Paulis
SUITE["traversal"]["combine"] = BenchmarkGroup(["combine"])
SUITE["traversal"]["combine"]["10"] = @benchmarkable traversal(c, combine_paulis) setup=(c=make_pauli_circuit(10)) evals=1
SUITE["traversal"]["combine"]["100"] = @benchmarkable traversal(c, combine_paulis) setup=(c=make_pauli_circuit(100)) evals=1
SUITE["traversal"]["combine"]["1000"] = @benchmarkable traversal(c, combine_paulis) setup=(c=make_pauli_circuit(1000)) evals=1

# Mixed circuit traversal
SUITE["traversal"]["mixed"] = BenchmarkGroup(["mixed"])
SUITE["traversal"]["mixed"]["swap_100"] = @benchmarkable traversal(c, swap_transform) setup=(c=make_mixed_circuit(100)) evals=1
SUITE["traversal"]["mixed"]["noop_100"] = @benchmarkable traversal(c, noop_transform) setup=(c=make_mixed_circuit(100)) evals=1

# Direction comparison
SUITE["traversal"]["direction"] = BenchmarkGroup(["direction"])
SUITE["traversal"]["direction"]["right_100"] = @benchmarkable traversal(c, swap_transform, :right) setup=(c=make_pauli_circuit(100)) evals=1
SUITE["traversal"]["direction"]["left_100"] = @benchmarkable traversal(c, swap_transform, :left) setup=(c=make_pauli_circuit(100)) evals=1
