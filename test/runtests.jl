using ArtifactUtils
using Test
using TOML

@testset "ArtifactUtils.jl" begin
    artifact_file = joinpath(mktempdir(), "Artifacts.toml")
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
    rm(artifact_file)
end
