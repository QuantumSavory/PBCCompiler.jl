push!(LOAD_PATH, "../src/")

using Documenter
using PBCCompiler

DocMeta.setdocmeta!(PBCCompiler, :DocTestSetup, :(using QuantumClifford, PBCCompiler); recursive=true)

makedocs(
    doctest = false,
    clean = true,
    warnonly = :missing_docs,
    sitename = "PBCCompiler.jl",
    format = Documenter.HTML(),
    modules = [PBCCompiler],
    authors = "Stefan Krastanov",
    pages = [
        "PBCCompiler.jl" => "index.md",
        "API" => "API.md",
    ]
)

deploydocs(
    repo = "github.com/QuantumSavory/PBCCompiler.jl.git"
)
