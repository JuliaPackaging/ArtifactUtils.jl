using ArtifactUtils, Pkg.Artifacts
using Base: SHA1
using Downloads
using Test
using TOML
import Pkg
import Git

# returns a run command that can be interpolated into
# julia run commands, and acts like a fake, local-only gh
fake_gh(release_dir) = addenv(
    `$(Base.julia_cmd()) $(joinpath(@__DIR__, "fake_gh.jl"))`,
    "FAKE_GH_RELEASE_DIR" => release_dir,
)

function _artifact(name, loc)
    eval(Expr(:macrocall, Symbol("@artifact_str"), LineNumberNode(1, Symbol(loc)), name))
end

expected_artifacts = Dict{String,Any}(
        "JuliaMono" => Dict{String,Any}(
            "git-tree-sha1" => "65279f9c8a3dd1e2cb654fdedbe8cd58889ae1bc",
            "download" => Any[
                Dict{String,Any}(
                    "sha256" => "f1ab65231cda7981531398644a58fd5fde8f367b681e1b8e9c35d9b2aacfcb1c",
                    "url" => "https://github.com/cormullion/juliamono/releases/download/v0.007/JuliaMono.tar.gz",
                    "size" => Int64(5752883),
                ),
            ],
        ),
    )
expected_artifacts_nosize = deepcopy(expected_artifacts)
delete!(expected_artifacts_nosize["JuliaMono"]["download"][1], "size")

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
        @test artifacts == expected_artifacts || artifacts == expected_artifacts_nosize
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
        Int64(5752883),
        false,
    )
    mktempdir() do tempdir
        artifact_file = joinpath(tempdir, "Artifacts.toml")
        add_artifact!(artifact_file, "JuliaMono", gist)
        artifacts = TOML.parsefile(artifact_file)
        @test artifacts == expected_artifacts || artifacts == expected_artifacts_nosize
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

@testset "fake_gh" begin
    mktempdir() do release_dir
        gh = fake_gh(release_dir)

        @testset "repo view" begin
            @test readchomp(`$gh repo view --json nameWithOwner -q .nameWithOwner`) == "test-owner/ArtifactUtils.jl"
        end

        @testset "release create" begin
            run(`$gh release create v1.0`)
            @test isdir(joinpath(release_dir, "v1.0"))
        end

        @testset "release upload" begin
            src = joinpath(release_dir, "artifact.tar.gz")
            write(src, "test content")
            run(`$gh release upload v1.0 $src --repo owner/repo --clobber`)
            @test read(joinpath(release_dir, "v1.0", "artifact.tar.gz"), String) == "test content"
            # we never created v1.1, should error
            @test_throws ProcessFailedException run(`$gh release upload v1.1 $src --repo owner/repo --clobber`)

        end
    end
end

@testset "release utils" begin
    @testset "get_repo_name" begin
        # just test repo name, not owner, otherwise fails for people writing PR's.
        @test last(split(ArtifactUtils.get_repo_name(), "/")) == "ArtifactUtils.jl"
    end

    @testset "release_from_file" begin
        mktempdir() do tmpdir
            # create a small test file
            # use a random int to ensure its always overwriting the test file
            filepath = joinpath(tmpdir, "test.txt")
            random_int = string(rand(Int))
            write(filepath, random_int)

            # Try to create a release, but if anything errors, carry on so we can delete the release
            tag = "test"
            try
                url = ArtifactUtils.release_from_file(filepath; tag=tag)
                sleep(5) # make sure theres enough time for it to upload
                downloaded = joinpath(tmpdir, "downloaded.txt")
                Downloads.download(url, downloaded)
                @test read(downloaded, String) == random_int
            catch err
                # if we got here, something above errored,
                # but we really should carry on so we can delete the
                # release if it was created
                showerror(stderr, err)
                @test false
            end

            # remove the release to avoid polluting releases.
            # if release was never created, i.e. code above failed,
            # this will error, hence the try/catch
            try
                gh = gh_cli_jll.gh()
                run(`$gh release delete $tag --cleanup-tag -y`)
            catch err
                showerror(stderr, err)
            end
        end
    end
end

@testset "upload_to_release" begin
    mktempdir() do tmp_dir
        # Create a small artifact
        src_dir = joinpath(tmp_dir, "src")
        mkpath(src_dir)
        filepath = joinpath(src_dir, "test.txt")
        random_int = string(rand(Int))
        write(filepath, random_int)
        artifact_id = artifact_from_directory(src_dir)

        tag = "test"
        try
            result = upload_to_release(artifact_id; tag=tag)

            # Check the result struct
            @test result.artifact_id == artifact_id
            @test result.tag == tag
            @test endswith(result.filename, ".tar.gz")
            @test startswith(result.url, "https://github.com/")
            @test !isempty(result.sha256)

            # make sure we can now add it as an artifact
            artifact_file = joinpath(tmp_dir, "Artifacts.toml")
            add_artifact!(artifact_file, "test_gh_release_artifact", result)
            artifacts = TOML.parsefile(artifact_file)
            # Verify the artifact was bound in the TOML
            @test haskey(artifacts, "test_gh_release_artifact")
            @test artifacts["test_gh_release_artifact"]["git-tree-sha1"] == bytes2hex(result.artifact_id.bytes)

            # Instantiate the artifact and check the file contents
            artifact_dir = ensure_artifact_installed("test_gh_release_artifact", artifact_file)
            @test read(joinpath(artifact_dir, "test.txt"), String) == random_int
        catch err
            # if we got here, something above errored,
            # but we really should carry on so we can delete the
            # release if it was created
            showerror(stderr, err)
            @test false
        end

        # remove the release to avoid polluting releases
        # if release was never created, i.e. code above failed,
        # this will error, hence the try/catch
        try
            gh = gh_cli_jll.gh()
            run(`$gh release delete $tag --cleanup-tag -y`)
        catch err
            showerror(stderr, err)
        end
    end
end
