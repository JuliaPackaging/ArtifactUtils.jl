"""
    gist_from_file(filepath::AbstractString; private::Bool = true) -> fileurl::String

Create a new gist from file at `filepath`. Return the "raw" HTTPS URL of the file.
"""
function gist_from_file(filepath::AbstractString; private::Bool = true)
    @assert isfile(filepath)
    # Using `with_new_gist` utility defined below instead of simply calling `gh gist create
    # $filepath`. This seems to be required when the file at `filepath` is not a text file.
    repo_http = with_new_gist(; private = private) do git_dir
        cp(filepath, joinpath(git_dir, basename(filepath)))
    end
    return rstrip(repo_http, '/') * "/raw/" * basename(filepath)
end

"""
    with_new_gist(f; private::Bool = true) -> repo_http::AbstractString

Create a new gist, check it out as a local git repository at a temporary directory
`git_dir`, call `f(git_dir)`, and then push it to remote.  Return the canonical gist HTTPS
URL.
"""
function with_new_gist(f; private::Bool = true)
    cmd = gh_cli_jll.gh()
    cmd = `$cmd gist create`
    if !private
        cmd = `$cmd --public`
    end
    repo_http = chomp(String(communicate(cmd, "dummy")))

    m = match(r"https://gist.github.com/(.*)", repo_http)
    if m === nothing
        error("Unrecognized output from `gh cli`: ", repo_http)
    end
    slug = m[1]
    git_url = "git@gist.github.com:$slug"

    response = Ref{HTTP.Response}()
    @sync begin
        # Get https://gist.github.com/$user/$slug from https://gist.github.com/$slug
        @async response[] = HTTP.head(repo_http; redirect = false)

        mktempdir() do git_dir
            git(args) = run(`$(Git.git()) -C $git_dir $args`)
            git(`clone $git_url .`)
            git_empty_history(git_dir)
            f(git_dir)
            git(`add .`)
            git(`commit --allow-empty -m "Add files"`)
            git(`push origin --force-with-lease`)
        end
    end

    return get(Dict(response[].headers), "Location", repo_http)
end

"""
    git_empty_history(git_dir)

Empty the history of the current branch. Create an empty commit to start fresh.
"""
function git_empty_history(git_dir)
    git(args) = run(`$(Git.git()) -C $git_dir $args`)
    branch = strip(read(`git -C $git_dir rev-parse --abbrev-ref HEAD`, String))
    git(`checkout --orphan=__tmp__`)
    for path in readdir(git_dir; join = true)
        basename(path) == ".git" && continue
        rm(path)
    end
    git(`add .`)
    git(`commit --allow-empty -m "Initial commit"`)
    git(`checkout $branch`)
    git(`reset --hard __tmp__`)
    return
end

"""
    communicate(cmd, input) -> output::Vector{UInt8}

Run `cmd`, write `input` to its stdin, and return the bytes `output` read from its stdout.
stderr is redirected to `Base.stdout`.
"""
function communicate(cmd, input)
    ipipe = Pipe()
    opipe = Pipe()
    proc = run(pipeline(cmd; stdin = ipipe, stdout = opipe, stderr = stderr); wait = false)
    local output
    @sync try
        close(opipe.in)
        @async try
            write(ipipe, input)
        finally
            close(ipipe)
        end
        output = read(opipe)
        wait(proc)
    catch
        close(ipipe)
        close(opipe)
        rethrow()
    end
    return output
end
