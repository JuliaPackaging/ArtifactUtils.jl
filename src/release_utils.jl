"""
Uses `gh` to get the name of this repo, in the form owner/name.
Note that this will return the owner/name set in `gh repo set-default`.
"""
function get_repo_name()
    gh = gh_cli_jll.gh()
    repo_name = readchomp(`gh repo view --json nameWithOwner -q .nameWithOwner`)
    return repo_name
end

"""
Creates a github release and uploads files.
Essentially, it just runs:
`gh release create \$tag --repo \$repo`,
`gh release upload \$tag \$filepath --repo \$repo --clobber`.
Returns the url of the release.
"""
function release_from_file(filepath::AbstractString; tag::AbstractString, repo::AbstractString=get_repo_name(), title="Packaging tarballs $tag", notes="Packaging tarballs for Julia artifact system")
    @assert isfile(filepath)
    gh = gh_cli_jll.gh()
    # Create release if it doesn't exist yet
    @info "Creating release with tag $tag"
    try
        run(`$gh release create $tag --repo $repo  --title $title --notes $notes`)
    catch
        @info "Release $tag already exists, continuing..."
    end
    @info("Uploading files to $repo with tag $tag", filepath)
    run(`$gh release upload $tag $filepath --repo $repo --clobber`)
    return "https://github.com/$(repo)/releases/download/$(tag)/$(basename(filepath))"
end
