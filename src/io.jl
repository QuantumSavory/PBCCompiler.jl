using JLD2
using QuantumClifford
import Base: show
##
"""
    parse_input(filepath::String) -> Circuit

Read an OpenQASM 2.0 file and return a `Circuit`.

Supported gates: `h`, `s`, `sdg`, `t`, `tdg`, `x`, `y`, `z`, `cx`, `measure`.
Each gate is translated to `CircuitOp` variants:
- `h`   → three `ExpQuatPiPauli`: Z, X, Z
- `s`   → `ExpQuatPiPauli(P"Z")`
- `sdg` → `ExpQuatPiPauli(-P"Z")`
- `t`   → `ExpEighPiPauli(P"Z")`
- `tdg` → `ExpEighPiPauli(-P"Z")`
- `x/y/z` → `ExpHalfPiPauli`
- `cx q[c],q[t]` → `PauliConditional(P"Z", [c], P"X", [t])`
- `measure q[i] -> c[j]` → `Measurement(P"Z", j, [i])`

Header lines (`OPENQASM`, `include`, `qreg`, `creg`, `barrier`) are skipped.
"""
function parse_input(filepath::String)::Circuit
    circuit = Circuit()

    open(filepath) do file
        for raw in eachline(file)
            line = strip(raw)
            isempty(line) && continue
            startswith(line, "//") && continue
            any(startswith(line, pfx) for pfx in
                ("OPENQASM", "include", "qreg", "creg", "barrier")) && continue

            # measure q[i] -> c[j];
            m = match(r"^measure\s+\w+\[(\d+)\]\s*->\s*\w+\[(\d+)\];$", line)
            if m !== nothing
                q = parse(Int, m[1])+1
                c = parse(Int, m[2])+1
                push!(circuit, CircuitOp.Measurement(P"Z", c, [q]))
                continue
            end

            # cx q[ctrl],q[tgt];
            m = match(r"^[Cc][Xx]\s+\w+\[(\d+)\]\s*,\s*\w+\[(\d+)\];$", line)
            if m !== nothing
                ctrl = parse(Int, m[1])+1
                tgt  = parse(Int, m[2])+1
                push!(circuit, CircuitOp.PauliConditional(P"Z", [ctrl], P"X", [tgt]))
                continue
            end

            # ccx q[ctrl],q[ctrl],q[tgt];
            m = match(r"^[Cc][Cc][Xx]\s+\w+\[(\d+)\]\s*,\s*\w+\[(\d+)\],\s*\w+\[(\d+)\];$", line)
            if m !== nothing
                ctrl = [parse(Int, m[1])+1, parse(Int, m[2])+1]
                tgt  = parse(Int, m[3])+1
                push!(circuit, CircuitOp.PauliConditional(P"ZZ", ctrl, P"X", [tgt]))
                continue
            end

            # single-qubit gate: <name> q[i];
            m = match(r"^(\w+)\s+\w+\[(\d+)\];$", line)
            if m !== nothing
                gate = m[1]
                q    = parse(Int, m[2])+1
                append!(circuit, _single_qubit_ops(gate, q))
                continue
            end
        end
    end

    return circuit
end

# Internal: translate a single-qubit gate name to its CircuitOps.
function _single_qubit_ops(gate::AbstractString, q::Int)::Vector{CircuitOp.Type}
    if gate == "h"
        return CircuitOp.Type[
            CircuitOp.ExpQuatPiPauli(P"Z", [q]),
            CircuitOp.ExpQuatPiPauli(P"X", [q]),
            CircuitOp.ExpQuatPiPauli(P"Z", [q]),
        ]
    elseif gate == "s"
        return [CircuitOp.ExpQuatPiPauli(P"Z",  [q])]
    elseif gate == "sdg"
        return [CircuitOp.ExpQuatPiPauli(-P"Z", [q])]
    elseif gate == "t"
        return [CircuitOp.ExpEighPiPauli(P"Z",  [q])]
    elseif gate == "tdg"
        return [CircuitOp.ExpEighPiPauli(-P"Z", [q])]
    elseif gate == "x"
        return [CircuitOp.ExpHalfPiPauli(P"X",  [q])]
    elseif gate == "y"
        return [CircuitOp.ExpHalfPiPauli(P"Y",  [q])]
    elseif gate == "z"
        return [CircuitOp.ExpHalfPiPauli(P"Z",  [q])]
    else
        error("Unsupported gate: $gate")
    end
end

"""
    save(result::ComputerState, filepath::String)

Save the first four fields of `result.memory_state` (`pauli_qubits`, `magic_qubits`,
`measurement_results`, `StabilizerGroup`) to a `.jld2` file at `filepath`.
"""
function save(result::ComputerState, filepath::String)
    ms = result.memory_state
    JLD2.jldsave(filepath;
        pauli_qubits        = ms.pauli_qubits,
        magic_qubits        = ms.magic_qubits,
        measurement_results = ms.measurement_results,
        StabilizerGroup     = ms.StabilizerGroup,
    )
end
##
"""
    parse_QuantumClifford(filepath::String) -> Vector{AbstractOperation}

Read an OpenQASM 2.0 file and return a circuit as a vector of QuantumClifford
operations. Supports Clifford+T gates: `x`, `y`, `z`, `h`, `cx`, `s`, `sdg`,
`t`, `tdg`. Qubit indices are 1-based. T† is decomposed as T followed by S†.
"""
function parse_QuantumClifford(filepath::String)
    circuit = QuantumClifford.AbstractOperation[]
    qubit_map = Dict{String,Int}()
    qubit_offset = 0

    for raw_line in eachline(filepath)
        line = strip(raw_line)

        # Strip inline comments
        ci = findfirst("//", line)
        !isnothing(ci) && (line = strip(line[1:ci.start-1]))
        isempty(line) && continue

        # Skip directives that carry no gate information
        (startswith(line, "OPENQASM") || startswith(line, "include") ||
         startswith(line, "creg")     || startswith(line, "measure") ||
         startswith(line, "reset")    || startswith(line, "barrier") ||
         startswith(line, "gate")     || startswith(line, "opaque")) && continue

        # qreg declaration: build name[index] -> 1-based qubit number map
        m = match(r"^qreg\s+(\w+)\[(\d+)\]\s*;", line)
        if !isnothing(m)
            reg, sz = m.captures[1], parse(Int, m.captures[2])
            for i in 0:sz-1
                qubit_map["$(reg)[$(i)]"] = qubit_offset + i + 1
            end
            qubit_offset += sz
            continue
        end

        # Gate application — strip trailing semicolon then parse
        line = endswith(line, ";") ? line[1:end-1] : line
        m = match(r"^(\w+)\s*(.*)$", line)
        isnothing(m) && continue

        gate = lowercase(m.captures[1])
        args_str = strip(m.captures[2])

        # Drop any parenthesised parameter list (e.g. U(theta,phi,lambda))
        args_str = replace(args_str, r"\([^)]*\)" => "")
        args_str = strip(args_str)

        qargs = [strip(q) for q in split(args_str, ",") if !isempty(strip(q))]
        isempty(qargs) && continue

        qs = [get(qubit_map, q, nothing) for q in qargs]
        any(isnothing, qs) && continue  # skip unresolvable qubit references

        if gate == "x" && length(qs) == 1
            push!(circuit, sX(qs[1]))
        elseif gate == "y" && length(qs) == 1
            push!(circuit, sY(qs[1]))
        elseif gate == "z" && length(qs) == 1
            push!(circuit, sZ(qs[1]))
        elseif gate == "h" && length(qs) == 1
            push!(circuit, sHadamard(qs[1]))
        elseif (gate == "cx" || gate == "cnot") && length(qs) == 2
            push!(circuit, sCNOT(qs[1], qs[2]))
        elseif gate == "s" && length(qs) == 1
            push!(circuit, sPhase(qs[1]))
        elseif gate == "sdg" && length(qs) == 1
            push!(circuit, sInvPhase(qs[1]))
        elseif gate == "t" && length(qs) == 1
            push!(circuit, sT(qs[1]))
        elseif gate == "tdg" && length(qs) == 1
            # T† = S†·T, so apply T first then S†
            push!(circuit, sT(qs[1]))
            push!(circuit, sInvPhase(qs[1]))
        end
    end

    return circuit
end

"""
    get_T_count(circuit::Vector{QuantumClifford.AbstractOperation}) -> Int

Return the number of `sT` gates in `circuit`.
"""
function get_T_count(circuit::Vector{QuantumClifford.AbstractOperation})
    return count(op -> op isa sT, circuit)
end
