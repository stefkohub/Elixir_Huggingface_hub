
defmodule Huggingface_hub.Repository do
  use Agent, restart: :transient
  require Logger

  alias Huggingface_hub.RunCommand, as: Run
  alias Huggingface_hub.HfFolder
  alias Huggingface_hub.Constants
  alias Huggingface_hub.Hf_api

  @moduledoc """
        
  """

  defp start_link(initial_state) do
    check_git_versions()

    {:ok, huggingface_token} =
      cond do
        initial_state.use_auth_token === true -> HfFolder.get_token()
        is_binary(initial_state.use_auth_token) -> {:ok, initial_state.use_auth_token}
        true -> {:ok, ""}
      end

    initial_state = %{initial_state | huggingface_token: huggingface_token}
    res = Agent.start_link(fn -> initial_state end, name: __MODULE__)
    case res do
      {:ok, pid} -> pid
      {:error, {:already_started, pid}} ->
        Logger.warning("Repository already initialised. Overwriting previous one.")
        update_state(pid, initial_state)
        pid
      _ -> raise "Unexpected error in repository process initialisation"
    end
  end

  def get_state(pid) do
    Agent.get(pid, fn state -> state end)
  end

  defp update_state(pid, updates) do
    Agent.update(pid, fn state -> Map.merge(state, updates) end)
    get_state(pid)
  end

  def repository(args) do
    state = %{
      command_queue: [],
      huggingface_token: "",
      local_dir: Path.expand(Keyword.fetch!(args, :local_dir)),
      clone_from: Keyword.get(args, :clone_from, ""),
      repo_type: Keyword.get(args, :repo_type, ""),
      use_auth_token: Keyword.get(args, :use_auth_token, true),
      git_user: Keyword.get(args, :git_user, ""),
      git_email: Keyword.get(args, :git_email, ""),
      revision: Keyword.get(args, :revision, ""),
      private: Keyword.get(args, :private, false),
      skip_lfs_files: Keyword.get(args, :skip_lfs_files, false),
      pid: nil
    }
    pid = start_link(state)
    state = update_state(pid, %{pid: pid})

    File.mkdir_p(state.local_dir)

    repo =
      if state.clone_from !== "" do
        Logger.debug("Clone from: #{state.clone_from}")
        clone_from(state, state.clone_from)
      else
        if is_git_repo(state.local_dir) === true,
          do: Logger.debug("#{state.local_dir} is a valid git repo"),
          else:
            raise("If not specifying `clone_from`, you need to pass Repository a valid git clone. local_dir=#{state.local_dir}")
          Run.git(state.local_dir, "remote get-url origin").stdout
      end

    if state.huggingface_token != "" do
      user = Hf_api.whoami(state.huggingface_token)
      git_email = (state.git_email === "" && user["email"]) || state.git_email
      git_user = (state.git_user === "" && user["fullname"]) || state.git_user

      if git_user != "" and git_email != "",
        do: git_config_username_and_email(state.local_dir, git_user, git_email)

      lfs_enable_largefile(state.local_dir)
      git_credential_helper_store(state.local_dir)
      if state.revision != "", do: git_checkout(state, state.revision, true)
    end
    {pid, repo}
  end

  def is_git_repo(folder) do
    folder_exists = File.exists?(Path.join(folder, ".git"))
    res = Run.git(folder, "branch")
    folder_exists && res.exit_status === 0
  end

  def is_local_clone(folder, remote_url) do
    if is_git_repo(folder) do
      remotes = Run.git(folder, "remote -v")
      remote_url = String.replace(remote_url, ~r/https:\/\/.*@/, "https://")

      remotes =
        for remote <- String.split(remotes.stdout) do
          String.replace(remote, ~r/https:\/\/.*@/, "https://")
        end

      remote_url in remotes
    else
      false
    end
  end

  def is_tracked_with_lfs(filename) do
    folder = Path.dirname(filename)
    filename = Path.basename(filename)
    p = Run.git(folder, "check-attr -a #{filename}")

    attributes =
      if p.stdout != nil do
        p.stdout |> String.trim() |> String.split("\n")
      else
        []
      end

    found_lfs_tag = %{diff: false, filter: false, merge: false}

    attr =
      found_lfs_tag
      |> Enum.map(fn {tag, false} ->
        {tag,
         Enum.find_value(attributes, fn a ->
           a =~ " #{tag}: lfs"
         end)}
      end)

    Enum.all?(attr, fn {_k, v} -> v === true end)
  end

  def is_git_ignored(filename) do
    folder = Path.dirname(filename)
    filename = Path.basename(filename)
    p = Run.git(folder, "check-ignore #{filename}")
    !p.exit_status
  end

  def files_to_be_staged(pattern, folder) do
    p = Run.git(folder, "ls-files -mo #{pattern}")

    if p.stdout != nil && p.exit_status === 0 do
      p.stdout |> String.trim() |> String.split("\n")
    else
      []
    end
  end

  def is_tracked_upstream(folder) do
    p = Run.git(folder, "rev-parse --symbolic-full-name --abbrev-ref @{u}")

    if p.stdout != [] && p.exit_status === 0 do
      true
    else
      if p.stdout =~ "HEAD", do:
        raise "No branch checked out."
      false
    end
  end

  def commits_to_push(folder, upstream \\ "") do
    p = Run.git(folder, "cherry -v #{upstream}")

    if p.stdout != [] && p.exit_status === 0 do
      (p.stdout |> String.trim() |> String.split("\n") |> Enum.count()) - 1
    else
      raise "Error."
    end
  end

  def check_git_versions() do
    try do
      git_version = Run.git(".", "--version").stdout
      # Here I check exit_status since git-lfs --version is not always giving the correct output
      lfs_version =
        "git lfs status: #{(Run.gitlfs(".", "--version").exit_status == 0 && "OK") || "KO"}"

      Logger.info("#{git_version}#{lfs_version}")
    rescue
      err -> raise "Error: #{inspect(err)}"
    end
  end

  def clone_from(state_or_pid, repo_url, use_auth_token \\ "") do
    state = is_pid(state_or_pid) && get_state(state_or_pid) || state_or_pid
    token = if use_auth_token != "", do: use_auth_token, else: state.huggingface_token

    if token === "" and state.private == true,
      do:
        raise("""
          Couldn't load Hugging Face Authorization Token. Credentials are required to work with private repositories.
          Please login in using `huggingface-cli login` or provide your token manually with the `use_auth_token` key.
        """)

    repo_url =
      if repo_url =~ "huggingface.co" or
           (not (repo_url =~ "http") and Enum.count(String.split(repo_url, "/")) <= 2) do
        {repo_type, namespace, repo_id} = Hf_api.repo_type_and_id_from_hf_id(repo_url)
        state = update_state(state.pid, %{repo_type: (repo_type != "" && repo_type) || state.repo_type})

        repo_url =
          "#{Constants.hf_endpoint()}/" <>
            ((state.repo_type in Constants.repo_types_url_prefixes() &&
                Constants.repo_types_url_prefixes()[state.repo_type]) || "")

        repo_url =
          if token != "" do
            whoami_info = Hf_api.whoami(token)
            user = whoami_info["name"]
            orgs = whoami_info["orgs"]
            # TODO: Check what is the actual format of orgs 
            valid_organisations = for org <- orgs, do: org["name"]

            repo_url =
              String.replace(
                (namespace != "" && "#{repo_url}#{namespace}/#{repo_id}") ||
                  "#{repo_url}#{repo_id}",
                "https://",
                "https://user:#{token}@"
              )

            new_repo_url =
              if namespace === user or namespace in valid_organisations do
                new_repo_url =
                  Hf_api.create_repo(repo_id, token, namespace, state.private, repo_type, true)

                Logger.info("Created repo on: #{new_repo_url}")
                new_repo_url
              else
                repo_url
              end

            new_repo_url
          else
            (namespace != "" && "#{repo_url}#{namespace}/") || "#{repo_url}#{repo_id}"
          end
        repo_url
      else
        repo_url
      end

    clean_repo_url = String.replace(repo_url, ~r"https:\/\/.*@", "https://")

    try do
      Run.git(state.local_dir, "lfs install")

      if Enum.count(File.ls!(state.local_dir)) == 0 do
        Logger.warning("Cloning #{clean_repo_url} into local empty directory.")
        env = (state.skip_lfs_files === true && [{'GIT_LFS_SKIP_SMUDGE', '1'}]) || []
        # gitcmd = state.skip_lfs_files === true && "clone" || "lfs clone"
        # raise "env=#{inspect env}, gitcmd=#{gitcmd}"
        Run.git_progressbar(state.local_dir, "clone #{repo_url} .", env)
      else
        if is_git_repo(state.local_dir) === true do
          if is_local_clone(state.local_dir, repo_url) === true do
            Logger.warning("""
              #{state.local_dir} is already a clone of #{clean_repo_url}. 
              Make sure you pull the latest changes with `repo.git_pull()`
            """)
          else
            output = Run.git(state.local_dir, "remote get-url origin")

            error_msg = """
              Tried to clone #{clean_repo_url} in an unrelated git repository.\nIf you believe this is
              an error, please add a remote with the following URL: #{clean_repo_url}.
            """

            error_msg =
              error_msg <>
                unless output.exit_status != 0 do
                  clean_url = String.replace(output.stdout, ~r"https:\/\/.*@", "https://")
                  "\nLocal path has its origin defined as: #{clean_url}"
                end

            raise error_msg
          end
        else
          raise """
             Tried to clone a repository in a non-empty folder that isn't a git repository. If you really 
             want to do this, do it manually:\n
             git init && git remote add origin && git pull origin main\n
             or clone repo to a new folder and move your existing files there afterwards.
          """
        end
      end
    catch
      err -> raise "Error in git clone: #{inspect(err)}"
    end

    repo_url
  end

  def git_config_username_and_email(local_dir, git_user, git_email) do
    if git_user != "" do
      Run.git(local_dir, "config user.name #{git_user}")
    end

    if git_email != "" do
      Run.git(local_dir, "config user.email #{git_email}")
    end
  end

  def git_credential_helper_store(local_dir) do
    Run.git(local_dir, "config credential.helper store")
  end

  def lfs_enable_largefile(local_dir) do
    Run.git(local_dir, "config lfs.customtransfer.multipart.path huggingface-cli")

    Run.git(
      local_dir,
      "config lfs.customtransfer.multipart.args #{Constants.lfs_multipart_upload_command()}"
    )
  end

  @doc """
      Returns the current checked out branch.
  """
  def current_branch(local_dir) do
    Run.git(local_dir, "rev-parse --abbrev-ref HEAD").stdout
  end

  def git_checkout(state_or_pid, revision \\ "", create_branch_ok \\ false) do
    state = is_pid(state_or_pid) && get_state(state_or_pid) || state_or_pid
    try do
      result = Run.git(state.local_dir, "checkout #{revision}")
      Logger.warning("Checked out #{revision} from #{current_branch(state.local_dir)}.")
      Logger.warning(result.stdout)
    rescue
      err ->
        if create_branch_ok !== true, do: raise("Error in git checkout: #{inspect(err)}")

        try do
          result = Run.git(state.local_dir, "checkout -b #{revision}")

          Logger.warning(
            "Revision `#{revision}` does not exist. Created and checked out branch `#{revision}`."
          )

          Logger.warning(result.stdout)
        catch
          err -> raise "Error in git checkout branch: #{inspect(err)}"
        end
    end
  end

  def git_pull(state_or_pid, rebase \\ false, lfs \\ false) do
    state = is_pid(state_or_pid) && get_state(state_or_pid) || state_or_pid
    command = ((lfs === false && "pull") || "lfs pull") <> ((rebase === true && " --rebase") || "")
    Run.git_progressbar(state.local_dir, command)
  end

  def list_deleted_files(state_or_pid) do
    state = is_pid(state_or_pid) && get_state(state_or_pid) || state_or_pid
    git_status = Run.git(state.local_dir, "status -s")
    if git_status.stdout == "" do
      []
    else
      Enum.flat_map(String.split(git_status.stdout, "\n"), fn status ->
        split_status = String.split(status)
        if (status != "") and (Enum.at(split_status,0) =~ "D") do
          [String.trim(Enum.at(split_status,-1))]
        else
          []
        end
      end)
    end
  end 

  def lfs_track_func(state_or_pid, action, patterns, filename \\ false) do
    state = is_pid(state_or_pid) && get_state(state_or_pid) || state_or_pid
    patterns = (is_list(patterns) && patterns) || [patterns]
    maybe_filename = (filename && "--filename") || ""
    for pattern <- patterns do
      Run.git(state.local_dir, "lfs #{action} #{maybe_filename} #{pattern}")
    end
  end

  def lfs_track(state_or_pid, patterns, filename \\ false) do
    lfs_track_func(state_or_pid, "track", patterns, filename)
  end

  def lfs_untrack(state_or_pid, patterns) do
    lfs_track_func(state_or_pid, "untrack", patterns)
  end

  def auto_track_large_files(state_or_pid, pattern) do
    state = is_pid(state_or_pid) && get_state(state_or_pid) || state_or_pid
    deleted_files = list_deleted_files(state)
    files_to_be_tracked_with_lfs = 
      for filename <- (files_to_be_staged(pattern, state.local_dir) -- deleted_files) do
        path_to_file = Path.join(File.cwd!, [state.local_dir, filename])
        size_in_mb = File.stat!(path_to_file).size / (1024 * 1024)
        if size_in_mb >= 10 and not is_tracked_with_lfs(path_to_file) and not is_git_ignored(path_to_file) do
          lfs_track(state, filename)
          filename
        end
      end 
      |> Enum.filter(fn x -> x != nil end)
    # Cleanup the .gitattributes if files were deleted
    lfs_untrack(state, deleted_files)
    files_to_be_tracked_with_lfs
  end

  def git_add(state_or_pid, pattern \\ ".", auto_lfs_track \\ false) do
    state = is_pid(state_or_pid) && get_state(state_or_pid) || state_or_pid
    if auto_lfs_track === true do
      tracked_f = auto_track_large_files(state, pattern)
      if tracked_f === true, do:
        Logger.warning("Adding files tracked by Git LFS: #{tracked_f}. This may take a bit of time if the files are large.")
      tracked_f
    end
    result = Run.git(state.local_dir, "add -v #{pattern}")
    Logger.info("Adding to index:\n#{result.stdout}\n")
  end

  def git_commit(state_or_pid, commit_message \\ "commit files to HF hub") do
    state = is_pid(state_or_pid) && get_state(state_or_pid) || state_or_pid
    result = Run.git(state.local_dir, "commit -m #{commit_message} -v")
    Logger.info("Committed:\n#{result.stdout}\n")
    result
  end

  def lfs_prune(state_or_pid, recent \\ false) do
    state = is_pid(state_or_pid) && get_state(state_or_pid) || state_or_pid
    command = "lfs prune" <> ((recent && " --recent") || "")
    result = Run.git_progressbar(state.local_dir, command)
    Logger.info(result.stdout)
    result.stdout
  end

  def git_head_hash(state_or_pid) do
    state = is_pid(state_or_pid) && get_state(state_or_pid) || state_or_pid
    Run.git(state.local_dir, "rev-parse HEAD").stdout |> String.trim
  end

  def git_remote_url(state_or_pid) do
    state = is_pid(state_or_pid) && get_state(state_or_pid) || state_or_pid
    result = Run.git(state.local_dir, "config --get remote.origin.url")
    result.stdout
    |> String.replace(~r/https:\/\/.*@/, "https://")
    |> String.trim
  end

  def git_head_commit_url(state_or_pid) do
    state = is_pid(state_or_pid) && get_state(state_or_pid) || state_or_pid
    sha = git_head_hash(state)
    url = git_remote_url(state)
    URI.merge(url, "/commit/#{sha}") |> to_string()
  end

  def git_push(state_or_pid, upstream \\ "", blocking \\ true, auto_lfs_prune \\ false) do
    state = is_pid(state_or_pid) && get_state(state_or_pid) || state_or_pid
    command = "push" <> ((upstream != "" && " --set-upstream #{upstream}") || "")
    number_of_commits = commits_to_push(state.local_dir, upstream)
    Logger.debug("number_of_commits=#{number_of_commits}")

    if number_of_commits > 1 do
      Logger.warning("Several commits (#{number_of_commits}) will be pushed upstream.")
      blocking && Logger.warning("The progress bars may be unreliable.")
    end
    if blocking do
      Run.git_progressbar(state.local_dir, command)
    end
    # TODO: Add non-blocking behavior

    auto_lfs_prune && lfs_prune(state)

    git_head_commit_url(state)
  end

  def commit(state_or_pid, args, func) do
    commit_message = Keyword.fetch!(args, :commit_message)
    branch = Keyword.get(args, :branch, "")
    track_large_files = Keyword.get(args, :track_large_files, "")
    blocking = Keyword.get(args, :blocking, "")
    auto_lfs_prune = Keyword.get(args, :auto_lfs_prune, false)

    state = is_pid(state_or_pid) && get_state(state_or_pid) || state_or_pid
    files_to_stage = files_to_be_staged(".", state.local_dir)
    if Enum.count(files_to_stage) > 5 do
      files_to_stage = files_to_stage |>Enum.take(5)|>Enum.join(", ")|>then(fn x -> "[#{x}, ...]" end)
      Logger.error(
        """
        There exists some updated files in the local repository that are not committed: #{files_to_stage}. 
        This may lead to errors if checking out a branch. 
        These files and their modifications will be added to the current commit.
        """)
    end
    if branch != "", do: git_checkout(state, branch, true)
    if is_tracked_upstream(state.local_dir) do
      Logger.warning("Pulling changes...")
      git_pull(state, true)
    else
      Logger.warning("The current branch has no upstream branch. Will push to 'origin #{current_branch(state.local_dir)}'")
    end
    cwd = File.cwd!
    # Non mi trovo: File.cd!(Path.join(cwd, state.local_dir))
    File.cd!(state.local_dir)
    func.()
    git_add(state, ".", track_large_files)
    res = git_commit(state, commit_message)
    unless res.exit_status == 0 or res.stdout =~ "nothing to commit", do:
      raise "Error in commit: #{res.stdout}"
    res = git_push(state, "origin #{current_branch(state.local_dir)}", blocking, auto_lfs_prune)
    #if res.exit_status != 0 do
    #  if res.stdout =~ "could not read Username" do
    #    raise "Couldn't authenticate user for push. Did you set `use_auth_token` to `True`?"
    #  else 
    #    raise "Error in push: #{res.stdout}"
    #  end
    #end
    File.cd!(cwd)
  end

  def is_repo_clean(state_or_pid) do
    state = is_pid(state_or_pid) && get_state(state_or_pid) || state_or_pid
    git_status = Run.git(state.local_dir, "status --porcelain").stdout |> String.trim
    String.length(git_status) === 0
  end

  def push_to_hub(state_or_pid, args \\ []) do
    commit_message = Keyword.get(args, :commit_message, "commit files to HF hub")
    blocking = Keyword.get(args, :blocking, true)
    clean_ok = Keyword.get(args, :clean_ok, true)
    auto_lfs_prune = Keyword.get(args, :auto_lfs_prune, false)

    state = is_pid(state_or_pid) && get_state(state_or_pid) || state_or_pid

    if clean_ok and is_repo_clean(state) do
      Logger.info("Repo currently clean. Nothing to push.")
    else
      git_add(state, ".", true)
      git_commit(state, commit_message)
      git_push(state, "origin #{state.current_branch}", blocking, auto_lfs_prune)
    end

  end
end
