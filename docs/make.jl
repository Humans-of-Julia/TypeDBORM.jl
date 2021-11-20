using TypeDBORM
using Documenter

DocMeta.setdocmeta!(TypeDBORM, :DocTestSetup, :(using TypeDBORM); recursive=true)

makedocs(;
    modules=[TypeDBORM],
    authors="Frank Urbach",
    repo="https://github.com/Humans-of-Julia/TypeDBORM.jl/blob/{commit}{path}#{line}",
    sitename="TypeDBORM.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://Humans-of-Julia.github.io/TypeDBORM.jl/dev",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
        "Guide" => "guide.md",
        "Structural Infos" => "structural_infos.md",
    ],
)

deploydocs(;
    repo="GitHub.com/Humans-of-Julia/TypeDBORM.jl.git",
)
