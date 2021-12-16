using ArtifactUtils
using Documenter

makedocs(;
    modules=[ArtifactUtils],
    authors="Simeon Schaub <simeondavidschaub99@gmail.com> and contributors",
    repo="https://github.com/simeonschaub/ArtifactUtils.jl/blob/{commit}{path}#L{line}",
    sitename="ArtifactUtils.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://simeonschaub.github.io/ArtifactUtils.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
        hide("Internals" => "internals.md"),
    ],
)

deploydocs(;
    repo="github.com/simeonschaub/ArtifactUtils.jl",
)
