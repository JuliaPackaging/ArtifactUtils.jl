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

julia> import Pkg; Pkg.ensure_artifact_installed("JuliaMono", "Artifacts.toml")
 Downloading artifact: JuliaMono
 Downloading artifact: JuliaMono
"/home/simeon/.julia/artifacts/6c460cf2eccecd24499618112adbbe7e403fa1ee"

julia> artifact"JuliaMono"
"/home/simeon/.julia/artifacts/6c460cf2eccecd24499618112adbbe7e403fa1ee"

julia> run(`ls $ans`);
JuliaMono-Black.ttf
JuliaMono-BoldLatin.ttf
JuliaMono-Bold.ttf
JuliaMono-ExtraBold.ttf
JuliaMono-Light.ttf
JuliaMono-Medium.ttf
JuliaMono-RegularLatin.ttf
JuliaMono-Regular.ttf
LICENSE
```

### Archive a directory and upload it to gist

You can create an artifact from a directory using `artifact_from_directory` and
then upload it to gist with `upload_to_gist`.  Note that `upload_to_gist`
requires login with the [GitHub CLI `gh`](https://github.com/cli/cli).

```julia
julia> using ArtifactUtils

julia> tempdir = mktempdir();

julia> write(joinpath(tempdir, "file"), "hello");

julia> artifact_id = artifact_from_directory(tempdir)
SHA1("538e83d637ab07ada6d841aa2454e0d5af4e52b3")

julia> gist = upload_to_gist(artifact_id)
- Creating gist...
✓ Created gist
Cloning into '.'...
Switched to a new branch '__tmp__'
[__tmp__ (root-commit) a1c4820] Initial commit
Switched to branch 'main'
Your branch is up to date with 'origin/main'.
HEAD is now at a1c4820 Initial commit
[main 2b03e65] Add files
 1 file changed, 0 insertions(+), 0 deletions(-)
 create mode 100644 538e83d637ab07ada6d841aa2454e0d5af4e52b3.tar.gz
To gist.github.com:4e2e8dacc2179149b047d6f60885389e
 + 5b04880...2b03e65 main -> main (forced update)
upload_to_gist(SHA1("538e83d637ab07ada6d841aa2454e0d5af4e52b3")) →

[538e83d637ab07ada6d841aa2454e0d5af4e52b3]
git-tree-sha1 = "538e83d637ab07ada6d841aa2454e0d5af4e52b3"

    [[538e83d637ab07ada6d841aa2454e0d5af4e52b3.download]]
    sha256 = "5f25c71dbebe1c7eeda5b2480360e5815ec530c22f27d1e7c4f87d73aac4aeb9"
    url = "https://gist.github.com/simeonschaub/4e2e8dacc2179149b047d6f60885389e/raw/538e83d637ab07ada6d841aa2454e0d5af4e52b3.tar.gz"
```

You can copy-and-paste the printed artifact fragment into your `Artifacts.toml`
file.  You can also call `add_artifact!` with the `gist` result object.

```julia
julia> add_artifact!("Artifacts.toml", "hello_world", gist)
```
