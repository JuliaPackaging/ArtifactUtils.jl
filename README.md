# ArtifactUtils

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://JuliaPackaging.github.io/ArtifactUtils.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://JuliaPackaging.github.io/ArtifactUtils.jl/dev/)
[![Build Status](https://github.com/JuliaPackaging/ArtifactUtils.jl/workflows/CI/badge.svg)](https://github.com/JuliaPackaging/ArtifactUtils.jl/actions)
[![Coverage](https://codecov.io/gh/JuliaPackaging/ArtifactUtils.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/JuliaPackaging/ArtifactUtils.jl)
[![pkgeval](https://juliahub.com/docs/ArtifactUtils/pkgeval.svg)](https://juliahub.com/ui/Packages/ArtifactUtils/d8lJU)

Provides the function
[`add_artifact!`](https://JuliaPackaging.github.io/ArtifactUtils.jl/dev/#ArtifactUtils.add_artifact!-Tuple{String,String,String}),
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
  Downloaded artifact: JuliaMono
  Downloaded artifact: JuliaMono
"/home/simeon/.julia/artifacts/6c460cf2eccecd24499618112adbbe7e403fa1ee"

julia> artifact"JuliaMono"
"/home/simeon/.julia/artifacts/6c460cf2eccecd24499618112adbbe7e403fa1ee"

julia> run(`ls $ans`);
JuliaMono-Black.ttf	 JuliaMono-Bold.ttf	  JuliaMono-Light.ttf	JuliaMono-RegularLatin.ttf  LICENSE
JuliaMono-BoldLatin.ttf  JuliaMono-ExtraBold.ttf  JuliaMono-Medium.ttf	JuliaMono-Regular.ttf
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
remote: Enumerating objects: 3, done.
remote: Counting objects: 100% (3/3), done.
remote: Total 3 (delta 0), reused 0 (delta 0), pack-reused 0
Receiving objects: 100% (3/3), done.
Switched to a new branch '__tmp__'
[__tmp__ (root-commit) f5a58a9] Initial commit
Switched to branch 'master'
Your branch is up to date with 'origin/master'.
HEAD is now at f5a58a9 Initial commit
[master 44dfe9a] Add files
 1 file changed, 0 insertions(+), 0 deletions(-)
 create mode 100644 538e83d637ab07ada6d841aa2454e0d5af4e52b3.tar.gz
Counting objects: 5, done.
Delta compression using up to 128 threads.
Compressing objects: 100% (4/4), done.
Writing objects: 100% (5/5), 455 bytes | 455.00 KiB/s, done.
Total 5 (delta 1), reused 0 (delta 0)
remote: Resolving deltas: 100% (1/1), done.
To gist.github.com:a9ceed430ff970412fc6606ef1b84b6a
 + 2668e40...44dfe9a master -> master (forced update)
upload_to_gist(SHA1("538e83d637ab07ada6d841aa2454e0d5af4e52b3")) →

[538e83d637ab07ada6d841aa2454e0d5af4e52b3]
git-tree-sha1 = "538e83d637ab07ada6d841aa2454e0d5af4e52b3"

    [[538e83d637ab07ada6d841aa2454e0d5af4e52b3.download]]
    sha256 = "a530e9f7e371eeea4aa4fbce83a00ed32233b7766314670b1c0779eb46a7b68d"
    url = "https://gist.github.com/tkf/a9ceed430ff970412fc6606ef1b84b6a/raw/538e83d637ab07ada6d841aa2454e0d5af4e52b3.tar.gz"
```

You can copy-and-paste the printed artifact fragment into your `Artifacts.toml`
file.  You can also call `add_artifact!` with the `gist` result object.

```julia
julia> add_artifact!("Artifacts.toml", "hello_world", gist)
```
