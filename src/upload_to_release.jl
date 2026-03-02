using ghr_jll

struct ReleaseUploadResult
    artifact_id::SHA1
    filename::String
    localpath::Union{String,Nothing}
    url::String
    sha256::String
    tag::String
end

include("release_utils.jl")

"""
    upload_to_release(
        artifact_id::SHA1,
        [tarball];
        tag::AbstractString="artifacts-latest",
        honor_overrides = false,
        # Following options are aviailable only when `tarball` is not specified:
        name::AbstractString = "\$artifact_id.tar.gz",
        extension::AbstractString = ".tar.gz",
    ) -> release

Create an artifact archive at path `tarball` (or in a temporary location) and upload it to
release. The returned value `release` can be passed to `add_artifact!`.

# Extended help

## Examples
```julia
using ArtifactUtils
add_artifact!("Artifact.toml", "name", upload_to_release(artifact_from_directory("source")))
```

creates an artifact from files in the `"source"` directory, uploads it to a release, and then
adds it to `"Artifact.toml"` with the name `"name"`.

## Keyword Arguments
- `tag`: the tag of the release to upload to
- `name`: name of the archive file, including file extension
- `extension`: file extension of the tarball. It can be used for specifying the compression
  method.
- `honor_overrides`: see `Pkg.Artifacts.archive_artifact`
"""
function upload_to_release end

function upload_to_release(
    artifact_id::SHA1,
    tarball::AbstractString;
    tag::AbstractString="artifacts-latest",
    archive_options...,
)
    mkpath(dirname(tarball))
    archive_artifact(artifact_id, tarball; archive_options...)
    sha256 = sha256sum(tarball)
    url = release_from_file(tarball; tag=tag)
    return ReleaseUploadResult(
        artifact_id,
        basename(tarball),
        abspath(tarball),
        url,
        sha256,
        tag,
    )
end

function upload_to_release(
    artifact_id::SHA1;
    name::Union{AbstractString,Nothing}=nothing,
    extension::Union{AbstractString,Nothing}=nothing,
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
        upload_to_release(artifact_id, joinpath(dir, tarball); options...)
    end
end

"""
    add_artifact!(
        artifacts_toml::String,
        name::String,
        release::ReleaseUploadResult;
        options...,
    )

Extends the `add_artifact!` function to `ReleaseUploadResult`.
"""
function add_artifact!(
    artifacts_toml::String,
    name::String,
    release::ReleaseUploadResult;
    options...,
)
    bind_artifact!(
        artifacts_toml,
        name,
        release.artifact_id;
        download_info=[(release.url, release.sha256)],
        options...,
    )
end