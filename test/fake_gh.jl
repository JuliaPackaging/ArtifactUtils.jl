# fake gh CLI for testing release functionality without hitting GitHub.
# simulates repo view, release create, release upload
# uses FAKE_GH_RELEASE_DIR env var to be set to a writable directory.

release_dir = get(ENV, "FAKE_GH_RELEASE_DIR", "")
if isempty(release_dir)
    error("FAKE_GH_RELEASE_DIR not set")
end

if length(ARGS) < 2
    error("fake_gh: need at least 2 args")
end

cmd = join(ARGS[1:2], " ")

if cmd == "repo view"
    # we tried to get the repo name most likey,
    # so just return a fake
    print("test-owner/ArtifactUtils.jl")

elseif cmd == "release create"
    # tried to create a new release,
    # so here we just make new subdirectory
    # by the name of what would be the tag
    mkpath(joinpath(release_dir, ARGS[3]))

elseif cmd == "release upload"
    # tried to upload file to a release,
    # so here we just copy that file into the release directory
    # of the same tag.
    # we DO NOT make the path, as gh doesnt automatically
    # create a release when you try upload,
    # you must first create the release.
    tag, filepath = ARGS[3], ARGS[4]
    if !ispath(joinpath(release_dir, tag))
        error("fake_gh: release $tag not found")
    end
    cp(filepath, joinpath(release_dir, tag, basename(filepath)), force=true)

else
    error("fake_gh: unknown command: $(join(ARGS, " "))")
end
