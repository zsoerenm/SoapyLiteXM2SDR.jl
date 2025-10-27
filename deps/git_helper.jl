"""
Git helper functions for managing the litex_m2sdr repository during build.
"""

using LibGit2

"""
    ensure_repository(repo_url::String, repo_dir::String, commit_hash::String) -> LibGit2.GitRepo

Ensures that a git repository is cloned and checked out to a specific commit.

# Arguments
- `repo_url::String`: The URL of the git repository
- `repo_dir::String`: The local directory where the repository should be cloned
- `commit_hash::String`: The specific commit hash to check out

# Returns
- `LibGit2.GitRepo`: The opened git repository object

# Details
This function handles several scenarios:
1. If the repository doesn't exist, it clones it
2. If the repository exists but has a different remote URL, it deletes and re-clones
3. Always fetches the latest commits to ensure merge commits are available
4. Checks out the specified commit hash

This is particularly useful for CI environments where scratch spaces may be cached
between builds and the repository URL may change (e.g., from a fork to upstream).
"""
function ensure_repository(repo_url::String, repo_dir::String, commit_hash::String)
    repo = nothing

    if isdir(repo_dir)
        println("Repository already exists, checking remote URL...")
        repo = LibGit2.GitRepo(repo_dir)

        # Check if remote URL matches, if not delete and re-clone
        remote_url = try
            LibGit2.url(LibGit2.get(LibGit2.GitRemote, repo, "origin"))
        catch
            ""
        end

        if remote_url != repo_url
            println("Remote URL changed (was: $remote_url), deleting and re-cloning...")
            close(repo)
            rm(repo_dir; recursive=true, force=true)
            repo = LibGit2.clone(repo_url, repo_dir)
        else
            println("Updating existing repository...")
        end
    else
        println("Cloning repository from $repo_url...")
        repo = LibGit2.clone(repo_url, repo_dir)
    end

    # Always fetch to ensure we have the latest commits including merge commits
    println("Fetching latest commits...")
    LibGit2.fetch(repo; refspecs=["+refs/heads/*:refs/remotes/origin/*"])

    # Check out the specific commit
    println("Checking out commit: $commit_hash")
    obj = LibGit2.GitObject(repo, commit_hash)
    LibGit2.reset!(repo, obj, LibGit2.Consts.RESET_HARD)
    println("Checked out commit: $commit_hash")

    return repo
end
