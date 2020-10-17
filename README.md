# ArtifactUtils

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://simeonschaub.github.io/ArtifactUtils.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://simeonschaub.github.io/ArtifactUtils.jl/dev/)
[![Build Status](https://github.com/simeonschaub/ArtifactUtils.jl/workflows/CI/badge.svg)](https://github.com/simeonschaub/ArtifactUtils.jl/actions)
[![Coverage](https://codecov.io/gh/simeonschaub/ArtifactUtils.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/simeonschaub/ArtifactUtils.jl)

Provides the function
[`add_artifact!`](https://simeonschaub.github.io/ArtifactUtils.jl/dev/#ArtifactUtils.add_artifact!-Tuple{String,String,String}),
which makes it easy for Julia projects to ship their own tarballs as
[Artifacts](https://julialang.github.io/Pkg.jl/dev/artifacts/).

## Example

This will download the JuliaMono font from GitHub as a tarball and create a corresponding
`Artifacts.toml` file in the current directory. It allows any Julia code in that directory
to access these files with the `artifact"..."` string macro.

```julia
julia> using ArtifactUtils, Pkg.Artifacts # Pkg.Artifacts provides the artifact string macro

julia> add_artifact!(
           "Artifacts.toml",
           "JuliaMono",
           "https://github.com/cormullion/juliamono/releases/download/v0.021/JuliaMono.tar.gz",
           force=true,
       )
SHA1("888cda53d12753313f13b607a2655448bfc11be5")

julia> artifact"JuliaMono"
Downloading artifact: JuliaMono
curl: (22) The requested URL returned error: 404 Not Found
Downloading artifact: JuliaMono
######################################################################## 100.0%#=#=#
"/home/simeon/.julia/artifacts/888cda53d12753313f13b607a2655448bfc11be5"

julia> run(`ls $ans`);
JuliaMono-Black.ttf	JuliaMono-Bold.ttf	 JuliaMono-Light.ttf	JuliaMono-RegularLatin.ttf  LICENSE
JuliaMono-BoldLatin.ttf  JuliaMono-ExtraBold.ttf  JuliaMono-Medium.ttf	JuliaMono-Regular.ttf
```
