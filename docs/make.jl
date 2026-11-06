using Documenter
using PBCCompiler
using QuantumClifford

DocMeta.setdocmeta!(PBCCompiler, :DocTestSetup, :(using QuantumClifford, PBCCompiler); recursive=true)

makedocs(
    # Docstring doctests are run by the test suite (test/test_doctests.jl), so
    # they are not run again here. `@example` blocks in the manual still execute.
    doctest = false,
    clean = true,
    sitename = "PBCCompiler.jl",
    authors = "Stefan Krastanov",
    repo = Remotes.GitHub("QuantumSavory", "PBCCompiler.jl"),
    format = Documenter.HTML(
        prettyurls = get(ENV, "CI", nothing) == "true",
        canonical = "https://quantumsavory.github.io/PBCCompiler.jl/stable/",
        edit_link = "master",
    ),
    modules = [PBCCompiler],
    pages = [
        "Home" => "index.md",
        "Manual" => [
            "Circuits" => "manual/circuits.md",
            "Compilation pipeline" => "manual/compilation.md",
            "Execution and runtimes" => "manual/execution.md",
            "Input and output" => "manual/io.md",
            "Visualization" => "manual/visualization.md",
        ],
        "API reference" => "api.md",
    ],
)

deploydocs(
    repo = "github.com/QuantumSavory/PBCCompiler.jl.git",
    devbranch = "master",
    push_preview = true,
)
