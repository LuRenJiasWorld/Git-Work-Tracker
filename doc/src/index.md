# Git-Work-Tracker
> 自动跟踪你的每日Git活动！

```@docs
main(parameters::Dict{String, Union{String, Bool}} = Dict{String, Union{String, Bool}}())
```

```@docs
_mount_argparse()
```

```@docs
_scan_git_repositories(scan_dir::String)
```

```@docs
_read_git_repositories(path_list::Set{String},
                       all_branches::Bool,
                       date::String,
                       user::String)
```

```@docs
_read_git_repository(git_path::String,
                     all_branches::Bool,
                     date::String,
                     user::String)
```

```@docs
_run_git_command(dir::String, command::Cmd)
```