using ArtifactUtils, Pkg.Artifacts
using Base: SHA1
using Test
using TOML
import Pkg
import Git

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
        file = joinpath(tempdir, "hello.txt")
        open(file, write = true) do io
            println(io, "Hello, world.")
        end
        chmod(file, 0o644)
        @test SHA1(Pkg.GitTools.tree_hash(tempdir)) ==
              SHA1("0a890bd10328d68f6d85efd2535e3a4c588ee8e6")
        @test artifact_from_directory(tempdir) ==
              SHA1("0a890bd10328d68f6d85efd2535e3a4c588ee8e6")

        chmod(file, 0o744) # user x bit matters
        @test SHA1(Pkg.GitTools.tree_hash(tempdir)) ==
              SHA1("952cfce0fb589c02736482fa75f9f9bb492242f8")
        @test artifact_from_directory(tempdir) ==
              SHA1("952cfce0fb589c02736482fa75f9f9bb492242f8")
    end
end
# Hashes taken from:
# https://github.com/JuliaLang/Pkg.jl/blob/89286eac216164c43cc996f1f31a9fa1f1dacf87/test/new.jl#L2553-L2572

@testset "git_empty_history" begin
    mktempdir() do git_dir
        git(args) = run(`$(Git.git()) --no-pager -C $git_dir $args`)
        git(`init`)

        # Setup repository-local user name and email so that it works on CI
        git(`config user.email "test@example.com"`)
        git(`config user.name "tester"`)

        git(`checkout -b new-branch`)
        write(joinpath(git_dir, "file-1"), "content")
        git(`add file-1`)
        git(`commit --message "Add file-1"`)
        history = strip(read(`git -C $git_dir --no-pager log`, String))
        @test occursin("Add file-1", history)

        ArtifactUtils.git_empty_history(git_dir)
        @test !isfile("file-1")
        branch =
            strip(read(`git -C $git_dir --no-pager rev-parse --abbrev-ref HEAD`, String))
        @test branch == "new-branch"
        history = strip(read(`git -C $git_dir --no-pager log`, String))
        @test !occursin("Add file-1", history)
    end
end

@testset "open_atomic_write" begin
    mktemp() do path, io
        close(io)
        ArtifactUtils.open_atomic_write(path) do io
            println(io, "Hello, world.")
        end
        @test read(path, String) == "Hello, world.\n"
    end
    mktempdir() do tempdir
        path = joinpath(tempdir, "hello.txt")
        err = ErrorException("error from callback")
        @test_throws err ArtifactUtils.open_atomic_write(path) do io
            throw(err)
        end
        @test readdir(tempdir) == []
    end
end

@testset "threaded_progress_foreach" begin
    @testset for n in [10, 1000]
        hits = zeros(Int, n)
        ArtifactUtils.threaded_progress_foreach(eachindex(hits)) do i
            hits[i] += 1
        end
        @test all(==(1), hits)
    end
end

using Documenter, gh_cli_jll
if haskey(ENV, "GITHUB_TOKEN")
    @testset "Doctests" begin
        doctestfilters=[
            r"(/home/simeon)",
            r"\[__tmp__ \(root\-commit\)(.*)main -> main \(forced update\)"s,
            r"sha256 = \"(.*)\"",
            r"url = \"(.*)\"",
        ]
        dir = mktempdir()
        source = joinpath(dir, "src")
        mkdir(source)
        makedocs(;
            root = dir,
            source = source,
            sitename = "",
            doctest = :only,
            modules = [ArtifactUtils],
            doctestfilters,
        )
        url = TOML.parsefile(joinpath(dir, "Artifacts.toml"))["hello_world"]["download"][]["url"]
        @show url
        gh() do cmd
            run(`$cmd gist delete $url`)
        end
        rm(dir; recursive=true)
    end
else
    @warn "skipping doctests because `GITHUB_TOKEN` was not specified"
end
