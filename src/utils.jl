"""
    open_atomic_write(f, path) -> y

Evaluate `y = f(io::IO)`, atomically replace the file with a new file with the
content of `io` (in well-behaving file systems) and then return `y`; i.e., it's
an atomic version of `open(f, path; write = true)`.
"""
function open_atomic_write(f, path)
    # Resolve symlink so that we don't replace a symbolic link with a regular file
    path = realpath(path)
    tmppath, tmpio = mktemp(dirname(path); cleanup = false)
    y = try
        f(tmpio)
    finally
        close(tmpio)
    end
    mv(tmppath, path; force = true)  # atomically replace
    return y
end

"""
    threaded_progress_foreach(
        f,
        xs;
        nworkers::Integer = Sys.CPU_THREADS,
        progresstitle::AbstractString = "",
    )

Like `foreach(f, xs)` but threaded and with progress bar.
"""
function threaded_progress_foreach(
    f,
    xs;
    nworkers::Integer = Sys.CPU_THREADS,
    progresstitle::AbstractString = "",
)
    nitems = length(xs)  # so that it works even if `iterate(xs, _)` is impure
    queue = foldl(push!, xs, init = Channel{eltype(xs)}(nitems))
    close(queue)
    nworkers = min(nitems, nworkers)
    isdone = Threads.Atomic{Bool}(false)
    finished = Channel{Nothing}()
    @sync begin
        Threads.@spawn try
            @sync begin
                for _ in 1:nworkers
                    Threads.@spawn try
                        for x in queue
                            isdone[] && break  # something went wrong; finish early
                            f(x)
                            try
                                push!(finished, nothing)
                            catch
                                # Ignore thee error when it's due `close(finished)`:
                                isdone[] || rethrow()
                            end
                        end
                    catch
                        isdone[] = true
                        close(finished)
                        rethrow()
                    end
                end
            end
        finally
            close(finished)
        end
        # Putting this in `@spawn` as `@sync` does not handle exception in the
        # parent/root task.
        Threads.@spawn try
            @withprogress name = progresstitle begin
                for (i, _) in enumerate(finished)
                    @logprogress i / nitems
                end
            end
        finally
            isdone[] = true
            close(finished)
        end
    end
    return
end
