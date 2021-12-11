using ArtifactUtils, Pkg.Artifacts
using Base: SHA1
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

@testset "add_artifact!(_, _, ::GistUploadResult)" begin
    # Dummy `gist` result object
    gist = ArtifactUtils.GistUploadResult(
        SHA1("65279f9c8a3dd1e2cb654fdedbe8cd58889ae1bc"),
        "JuliaMono.tar.gz",
        "<localpath>",
        "https://github.com/cormullion/juliamono/releases/download/v0.007/JuliaMono.tar.gz",
        "f1ab65231cda7981531398644a58fd5fde8f367b681e1b8e9c35d9b2aacfcb1c",
        false,
    )
    mktempdir() do tempdir
        artifact_file = joinpath(tempdir, "Artifacts.toml")
        add_artifact!(artifact_file, "JuliaMono", gist)
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
    end
    str = sprint(show, "text/plain", gist)
    @test occursin("upload_to_gist(", str)
    @test occursin("; private = false)", str)
    @test occursin("url =", str)
end

@testset "artifact_from_directory" begin
    mktempdir() do tempdir
        write(joinpath(tempdir, "file"), "hello")
        @test artifact_from_directory(tempdir) ==
              SHA1("538e83d637ab07ada6d841aa2454e0d5af4e52b3")
    end
end

@testset "git_empty_history" begin
    if success(`git --help`)
        mktempdir() do git_dir
            git(args) = run(`git --no-pager -C $git_dir $args`)
            git(`init`)
            git(`checkout -b new-branch`)
            write(joinpath(git_dir, "file-1"), "content")
            git(`add file-1`)
            git(`commit --message "Add file-1"`)
            history = strip(read(`git -C $git_dir --no-pager log`, String))
            @test occursin("Add file-1", history)

            ArtifactUtils.git_empty_history(git_dir)
            @test !isfile("file-1")
            branch = strip(
                read(`git -C $git_dir --no-pager rev-parse --abbrev-ref HEAD`, String),
            )
            @test branch == "new-branch"
            history = strip(read(`git -C $git_dir --no-pager log`, String))
            @test !occursin("Add file-1", history)
        end
    end
end
