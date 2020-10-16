module ArtifactUtils

using Pkg.Artifacts
using Pkg.PlatformEngines
using Pkg.GitTools
using SHA

export add_artifact!

function sha256sum(tarball_path)
    return open(tarball_path, "r") do io
        return bytes2hex(sha256(io))
    end
end


"""
    function add_artifact!(
        artifacts_toml::String, name::String, tarball_url::String;
        clear=true,
        platform::Union{Platform,Nothing} = nothing,
        lazy::Bool = false,
        force::Bool = false
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
    clear=true,
    options...,
)
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

end
