# ArtifactUtils

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://simeonschaub.github.io/ArtifactUtils.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://simeonschaub.github.io/ArtifactUtils.jl/dev/)
[![Build Status](https://github.com/simeonschaub/ArtifactUtils.jl/workflows/CI/badge.svg)](https://github.com/simeonschaub/ArtifactUtils.jl/actions)
[![Coverage](https://codecov.io/gh/simeonschaub/ArtifactUtils.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/simeonschaub/ArtifactUtils.jl)
[![pkgeval](https://juliahub.com/docs/ArtifactUtils/pkgeval.svg)](https://juliahub.com/ui/Packages/ArtifactUtils/d8lJU)

Provides the function
[`add_artifact!`](https://simeonschaub.github.io/ArtifactUtils.jl/dev/#ArtifactUtils.add_artifact!-Tuple{String,String,String}),
which makes it easy for Julia projects to ship their own tarballs as
[Artifacts](https://julialang.github.io/Pkg.jl/dev/artifacts/).

## Example

This will download the JuliaMono font from GitHub as a tarball and create a corresponding
`Artifacts.toml` file in the current directory. It allows any Julia code in that directory
to access these files with the `artifact"..."` string macro.

```julia
julia> using ArtifactUtils, Artifacts # Artifacts provides the artifact string macro

julia> add_artifact!(
           "Artifacts.toml",
           "JuliaMono",
           "https://github.com/cormullion/juliamono/releases/download/v0.030/JuliaMono.tar.gz",
           force=true,
       )
SHA1("6c460cf2eccecd24499618112adbbe7e403fa1ee")

julia> import Pkg; Pkg.instantiate() # to install the artifact
  Downloaded artifact: JuliaMono
  Downloaded artifact: JuliaMono

julia> artifact"JuliaMono"
"/home/simeon/.julia/artifacts/6c460cf2eccecd24499618112adbbe7e403fa1ee"

julia> run(`ls $ans`);
JuliaMono-Black.ttf	JuliaMono-Bold.ttf	 JuliaMono-Light.ttf	JuliaMono-RegularLatin.ttf  LICENSE
JuliaMono-BoldLatin.ttf  JuliaMono-ExtraBold.ttf  JuliaMono-Medium.ttf	JuliaMono-Regular.ttf
```
