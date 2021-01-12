using ArtifactUtils, Pkg.Artifacts
using Test
using TOML
import Pkg

function _artifact(name, loc)
    eval(Expr(:macrocall, Symbol("@artifact_str"), LineNumberNode(1, Symbol(loc)), name))
end

@testset "ArtifactUtils.jl" begin
    mktempdir() do tempdir
        artifact_file = joinpath(tempdir, "Artifacts.toml")
        add_artifact!(
            artifact_file,
            "JuliaMono",
            "https://github.com/cormullion/juliamono/releases/download/v0.007/JuliaMono.tar.gz",
            force=true,
        )
        artifacts = TOML.parsefile(artifact_file)
        @test artifacts == Dict{String,Any}(
            "JuliaMono" => Dict{String,Any}(
                "git-tree-sha1" => "65279f9c8a3dd1e2cb654fdedbe8cd58889ae1bc",
                "download" => Any[
                    Dict{String,Any}(
                        "sha256" => "f1ab65231cda7981531398644a58fd5fde8f367b681e1b8e9c35d9b2aacfcb1c",
                        "url" => "https://github.com/cormullion/juliamono/releases/download/v0.007/JuliaMono.tar.gz",
                    ),
                ],
            ),
        )
        ensure_artifact_installed("JuliaMono", artifact_file)
        @test ispath(_artifact("JuliaMono", tempdir))
        hash = ArtifactUtils.sha256sum(joinpath(_artifact("JuliaMono", tempdir), "JuliaMono-Regular.ttf"))
        @test hash == "dc0af40e8bc944a5d38c049b9a5b33e80b1e7a9621ac30fb440e5a2b6a4192d7"
    end
end
