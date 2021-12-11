module ArtifactUtils

import HTTP
import TOML
import gh_cli_jll
using Pkg.Artifacts
using Pkg.PlatformEngines
using Pkg.GitTools
using Base: SHA1
using SHA
using Downloads: download

export add_artifact!, artifact_from_directory, upload_to_gist

include("gistutils.jl")

function sha256sum(tarball_path)
    return open(tarball_path, "r") do io
        return bytes2hex(sha256(io))
    end
end


"""
    function add_artifact!(
        artifacts_toml::String, name::String, tarball_url::String;
        clear=true,
        platform::Union{Platform,Nothing}=nothing,
        lazy::Bool=false,
        force::Bool=false
    )

Downloads tarball from `tarball_url`, extracts it and adds it as an artifact with name
`name` to the file `artifacts_toml`. If `clear` is true, the artifact itself is deleted
afterwards. The rest of the keyword arguments are passed to `Pkg.Artifacts.bind_artifact!`.

From [its docstring](https://julialang.github.io/Pkg.jl/dev/api/#Pkg.Artifacts.bind_artifact!):

> If `platform` is not `nothing`, this artifact is marked as platform-specific, and will be
> a multi-mapping.  It is valid to bind multiple artifacts with the same name, but
> different `platform`s and `hash`'es within the same `artifacts_toml`.  If `force` is set
> to `true`, this will overwrite a pre-existant mapping, otherwise an error is raised.
>
> [...] If `lazy`
> is set to `true`, even if download information is available, this artifact will not be
> downloaded until it is accessed via the `artifact"name"` syntax, or
> `ensure_artifact_installed()` is called upon it.
"""
function add_artifact!(
    artifacts_toml::String,
    name::String,
    tarball_url::String;
    clear = true,
    options...,
)
    @static isdefined(PlatformEngines, :probe_platform_engines!) &&
            probe_platform_engines!()

    tarball_path = download(tarball_url)
    sha256 = sha256sum(tarball_path)

    git_tree_sha1 = create_artifact() do artifact_dir
        unpack(tarball_path, artifact_dir)
    end

    rm(tarball_path)
    clear && remove_artifact(git_tree_sha1)

    bind_artifact!(
        artifacts_toml,
        name,
        git_tree_sha1;
        download_info = [(tarball_url, sha256)],
        options...,
    )

    return git_tree_sha1
end

"""
    artifact_from_directory(source) -> artifact_id::SHA1

Create an artifact from the `source` directory and return the `artifact_id`.
"""
artifact_from_directory(source) =
    create_artifact() do artifact_dir
        cp(source, artifact_dir; force = true, follow_symlinks = true)
    end

struct GistUploadResult
    artifact_id::SHA1
    filename::String
    localpath::Union{String,Nothing}
    url::String
    sha256::String
    private::Bool
end

"""
    upload_to_gist(
        artifact_id::SHA1,
        [tarball];
        private::Bool = true,
        archive_artifact = (),
        # Following options are aviailable only when `tarball` is not specified:
        name::AbstractString = "\$artifact_id.tar.gz",
        extension::AbstractString = ".tar.gz",
    ) -> gist

Create an artifact archive at path `tarball` (or in a temporary location) and upload it to
gist. The returned value `gist` can be passed to `add_artifact!`.

# Extended help

## Examples
```julia
using ArtifactUtils
add_artifact!("Artifact.toml", "name", upload_to_gist(artifact_from_directory("source")))
```

creates an artifact from files in the `"source"` directory, upload it to gist, and then
add it to `"Artifact.toml"` with the name `"name"`.

## Keyword Arguments
- `private`: if `true`, upload the archive to a private gist
- `archive_artifact`: keyword arguments passed to `Pkg.Artifacts.archive_artifact`
- `name`: name of the archive file, including file extension
- `extension`: file extension of the tarball. It can be used for specifying the compression
  method.
"""
function upload_to_gist end

function upload_to_gist(
    artifact_id::SHA1,
    tarball::AbstractString;
    private::Bool = true,
    archive_artifact = (),
)
    mkpath(dirname(tarball))
    (@__MODULE__).archive_artifact(artifact_id, tarball; archive_artifact...)
    sha256 = sha256sum(tarball)
    url = gist_from_file(tarball; private = private)
    return GistUploadResult(
        artifact_id,
        basename(tarball),
        abspath(tarball),
        url,
        sha256,
        private,
    )
end

function upload_to_gist(
    artifact_id::SHA1;
    name::Union{AbstractString,Nothing} = nothing,
    extension::Union{AbstractString,Nothing} = nothing,
    options...,
)
    if name !== nothing && extension !== nothing
        error(
            "Options `name` and `extension` are mutually exclusive. Got: name = ",
            name,
            " extension = ",
            extension,
        )
    end

    tarball = if name === nothing
        string(artifact_id, something(extension, ".tar.gz"))
    else
        name
    end

    return mktempdir() do dir
        upload_to_gist(artifact_id, joinpath(dir, tarball); options...)
    end
end

function add_artifact!(
    artifacts_toml::String,
    name::String,
    gist::GistUploadResult;
    options...,
)
    bind_artifact!(
        artifacts_toml,
        name,
        gist.artifact_id;
        download_info = [(gist.url, gist.sha256)],
        options...,
    )
end

print_artifact_entry(gist::GistUploadResult; options...) =
    print_artifact_entry(stdout, gist; options...)
function print_artifact_entry(
    io::IO,
    gist::GistUploadResult;
    name::AbstractString = replace(gist.filename, r"\.tar.[^\.]*$" => ""),
)
    dict = Dict(
        name => Dict(
            "git-tree-sha1" => string(gist.artifact_id),
            "download" => [Dict("url" => gist.url, "sha256" => gist.sha256)],
        ),
    )
    TOML.print(io, dict)
end

function Base.show(io::IO, ::MIME"text/plain", gist::GistUploadResult)
    print(io, upload_to_gist, "(")
    show(io, gist.artifact_id)
    if !gist.private
        print(io, "; private = false")
    end
    println(io, ") →")
    println(io)

    print(io, strip(sprint(print_artifact_entry, gist)))
end

end
