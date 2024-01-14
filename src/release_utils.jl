function release_from_file(filepath::AbstractString; tag::AbstractString)
    
    @assert isfile(filepath)

    # Get the repo name from the git remote url
    if !haskey(ENV, "GITHUB_TOKEN")
        @warn "For automatic github deployment, need GITHUB_TOKEN. Not found in ENV, attemptimg global git config."
    end

    origin_url = strip(chomp(read(`git config --get remote.origin.url`, String)))
    deploy_repo = "$(basename(dirname(origin_url)))/$(basename(origin_url))"
    deploy_repo = replace(deploy_repo, ".git" => "")

    # Upload tarballs to a special github release
    @info("Uploading tarballs to $(deploy_repo) tag `$(tag)`")

    ghr() do ghr_exe
        println(
            readchomp(
                `$ghr_exe -replace -u $(dirname(deploy_repo)) -r $(basename(deploy_repo)) $(tag) $(filepath)`,
            ),
        )
    end

    tarball_url = "https://github.com/$(deploy_repo)/releases/download/$(tag)/$(basename(filepath))"

    return tarball_url
end