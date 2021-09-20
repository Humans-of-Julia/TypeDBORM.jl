using TypeDBORM
using Documenter

DocMeta.setdocmeta!(TypeDBORM, :DocTestSetup, :(using TypeDBORM); recursive=true)

makedocs(;
    modules=[TypeDBORM],
    authors="Frank Urbach",
    repo="https://GitHub.com/FrankUrbach/TypeDBORM.jl/blob/{commit}{path}#{line}",
    sitename="TypeDBORM.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://FrankUrbach.github.io/TypeDBORM.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="GitHub.com/FrankUrbach/TypeDBORM.jl",
)
