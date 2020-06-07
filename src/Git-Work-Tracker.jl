# Git Work Tracker
# 跟踪目录下所有Git仓库当日Commit数据
# 包含所有分支中的如下数据：
# - 新增文件数
# - 删除文件数
# - 新增行数
# - 删除行数

# 配置软件包扫描目录，从当前目录扫描
(dir -> push!(LOAD_PATH, dirname(dir)))(string(@__DIR__, "/../"))

module GitWorkTracker

using ArgParse
using Dates
using PrettyTables

export main, _mount_argparse, _scan_git_repositories, _read_git_repositories, _read_git_repository, _run_git_command

IGNORE_PATH = Array{String, 1}([
    # Git的子目录
    "/.git/",
    # 一些第三方库
    "/node_modules",
    "/vendor",
    "/thinkphp",
    "/think",
    "/gradle",
    "/venv",
    # 暂时不会动的项目
    "/Firefox",
    "/ReactOS",
    "/go-common-master"
])

GIT_COMMAND = `git --no-pager`

"""
    main(parameters::Dict{String, Union{String, Bool}} = Dict{String, Union{String, Bool}}())

主函数入口，允许如下命令行参数被传入：
1. --scan-dir="/random/dir"     扫描目录，不指定默认为脚本执行的当前目录
2. --all-branches=true/false    是否扫描Git仓库的所有分支，默认为false
3. --date="2020-06-01"          输出某一天的数据，默认为当天
4. --user="Benjamin"            只输出某个特定用户的Commit统计，支持前缀匹配（无需输入全名），默认为所有用户

如果你想将本软件集成在其他代码中，可以直接调用main函数，示例：
```julia
main(Dict{String, Union{String, Bool}}(
    "all_branches"  =>  true,
    "user"          =>  "Benjamin Chris"
))
```

调用main函数传入的参数优先级高于命令行参数
"""
function main(parameters::Dict{String, Union{String, Bool}} = Dict{String, Union{String, Bool}}())
    # 解析命令行参数
    parsed_args = _mount_argparse()

    # 解析传入参数
    for (k, v) in parameters
        parsed_args[k] = v
    end

    # 输出参数列表
    arg_table = Array{Union{String, Bool, Missing}}(missing, length(parsed_args), 2)
    (function (i)
        for (arg, val) in parsed_args
            arg_table[i, 1] = arg
            arg_table[i, 2] = val
            i = i + 1
        end
        println("你传入的参数为:")
        pretty_table(arg_table, ["Key", "Value"])
    end)(1)

    # 开始扫描
    println("")
    println("开始扫描目录$(parsed_args["scan-dir"]):")
    paths_contains_git_repository = _scan_git_repositories(parsed_args["scan-dir"])

    # 开始解析
    println("")
    println("在目录下扫描到$(length(paths_contains_git_repository))个仓库，开始按照设定的规则进行解析:")
    statistics = _read_git_repositories(paths_contains_git_repository, parsed_args["all-branches"], parsed_args["date"], parsed_args["user"])

    # 输出结果
    println("")
    println("扫描完成！你在$(parsed_args["date"])的Git活动如下所示:")
    pretty_table([
        "Commits"               statistics["commits"];
        "Added Lines"           statistics["added_lines"];
        "Removed Lines"         statistics["removed_lines"];
        "Added Files"           statistics["added_files"];
        "Modified Files"        statistics["modified_files"];
        "Removed Files"         statistics["removed_files"];
    ], [
        "Git Opration Type"     "Operation Count";
    ])
end

"""
    _mount_argparse()

读取并装载传入的参数，使用`@add_arg_table!`宏完成参数配置*（元编程真方便啊）*
"""
function _mount_argparse()
    s = ArgParseSettings()
    @add_arg_table! s begin
        "--scan-dir"
            help = "扫描目录，不指定默认为脚本执行的当前目录"
            arg_type = String
            default = pwd()
        "--all-branches"
            help = "是否扫描Git仓库的所有分支，默认为false"
            arg_type = Bool
            default = false
        "--date"
            help = "输出某一天的数据，默认为当天"
            arg_type = String
            default = Dates.format(Dates.now(), "yyyy-mm-dd")
        "--user"
            help = "筛选指定的用户名（用于多人协作开发场景）"
            arg_type = String
            default = ""
    end

    return parse_args(s)
end

"""
    _scan_git_repositories(scan_dir::String)

给定一个目录，自动扫描目录下所有包含`.git`子目录的目录，最后返回一个包含所有『包含Git的目录』的数组
"""
function _scan_git_repositories(scan_dir::String)
    dir_list = Set{String}()

    dir_count = 0
    ignore_dir_count = 0

    for (root, dirs, files) in walkdir(scan_dir)
        dir_count = dir_count + 1

        if length(findall(x -> occursin(x, root), IGNORE_PATH)) != 0
            ignore_dir_count = ignore_dir_count + 1
            continue
        end

        if length(root) > displaysize(stdout)[2] - 20
            dir_name = string(first(root, displaysize(stdout)[2] - 40), "...")
        else
            dir_name = root
        end

        _overprint("正在扫描目录$(dir_name)")

        if length(findall(r"\.git$", root)) != 0
            push!(dir_list, replace(root, r"\.git$" => ""))
        end
    end

    _overprint("目录扫描完成，扫描了$(dir_count)个目录，忽略了$(ignore_dir_count)个目录，扫描到$(length(dir_list))个Git目录")

    return dir_list
end

"""
    _read_git_repositories(path_list::Set{String},
                           all_branches::Bool,
                           date::String
                           user::String)

根据传入参数读取所有`path_list`中的Git仓库，获得相关统计数据
"""
function _read_git_repositories(path_list::Set{String},
                                all_branches::Bool,
                                date::String,
                                user::String)
    statistics = Dict{String, Integer}(
        "added_lines"      =>      0,
        "removed_lines"    =>      0,
        "added_files"      =>      0,
        "modified_files"   =>      0,
        "removed_files"    =>      0,
        "commits"          =>      0
    )

    path_count = 0

    for each_path in path_list
        path_count = path_count + 1
        _overprint("正在解析仓库$(path_count)/$(length(path_list))：$(each_path)")

        try
            current_statistics = _read_git_repository(each_path, all_branches, date, user)

            statistics["added_lines"]      = statistics["added_lines"]      + current_statistics["added_lines"]
            statistics["removed_lines"]    = statistics["removed_lines"]    + current_statistics["removed_lines"]
            statistics["added_files"]      = statistics["added_files"]      + current_statistics["added_files"]
            statistics["modified_files"]   = statistics["modified_files"]   + current_statistics["modified_files"]
            statistics["removed_files"]    = statistics["removed_files"]    + current_statistics["removed_files"]
            statistics["commits"]          = statistics["commits"]          + current_statistics["commits"]
        catch e
            bt = catch_backtrace()
            msg = sprint(showerror, e, bt)
            println("解析$(each_path)时出现错误，错误信息为\n$(msg)")
        end
    end

    _overprint("所有$(length(path_list))个仓库解析完成！")

    return statistics
end

"""
    _read_git_repository(git_path::String,
                         all_branches::Bool,
                         date::String
                         user::String)

读取每个Git仓库中的以下内容：
1. 新增行数
2. 删除行数
3. 新增文件数
4. 修改文件数
5. 删除文件数
6. 提交数
"""
function _read_git_repository(git_path::String,
                              all_branches::Bool,
                              date::String,
                              user::String)

    # 1. 分支检查
    branches = Array{String, 1}()
    if all_branches == true
        # 获取所有分支列表
        branch_list_raw = _run_git_command(git_path, `branch -a`)
        for each in branch_list_raw
            matched = match(r"[ ]([\S]+$)", each)
            if typeof(matched) == RegexMatch && length(matched.offsets) == 1
                branch_name = matched[1]
                push!(branches, branch_name)
            end
        end
    else
        # 仅master分支
        push!(branches, "master")
    end

    # 2. 获取每个分支中的每个commit编号，使用Array让其按时间顺序排列（第三步可以极大优化性能）
    commit_id = Array{String, 1}()
    for each_branch in branches
        commit_log = _run_git_command(git_path, `log --first-parent $each_branch --author "$user"`)
        for each_commit_log_line in commit_log
            matched_line = match(r"^commit ([a-z0-9]{40})", each_commit_log_line)
            if typeof(matched_line) == RegexMatch && length(matched_line.offsets) == 1
                # 去重
                current_commit_id = matched_line[1]
                if (length(findall(x -> x == current_commit_id, commit_id)) == 0)
                    push!(commit_id, current_commit_id)
                end
            end
        end
    end

    # 3. 获取每个Commit的信息，将其与date比对，如果比对一致，则解析其中的各项数据
    statistics = Dict{String, Integer}(
        "added_lines"       =>      0,
        "removed_lines"     =>      0,
        "added_files"       =>      0,
        "modified_files"    =>      0,
        "removed_files"     =>      0,
        "commits"           =>      0
    )

    for each_commit in commit_id
        commit_patch = _run_git_command(git_path, `show $each_commit --date=short`)
        # 检查日期
        commit_date = ""

        for each_patch in commit_patch
            current_match = match(r"Date:[\s]+([0-9]{4}-[0-9]{2}-[0-9]{2})", each_patch)
            if typeof(current_match) == RegexMatch && length(current_match.offsets) == 1
                commit_date = current_match[1]
                break
            end
        end

        if commit_date == date
            # 今日Commit+1
            statistics["commits"] = statistics["commits"] + 1

            # 获取行数增减情况
            commit_lines_info = _run_git_command(git_path, `show $each_commit --stat --date=short`)
            last_commit_line_info = commit_lines_info[length(commit_lines_info)]

            insertions = match(r"([\d]+) insertion", last_commit_line_info)
            deletions  = match(r"([\d]+) deletion" , last_commit_line_info)

            if (typeof(insertions) == RegexMatch)
                statistics["added_lines"]   = statistics["added_lines"]    + parse(Int, insertions[1])
            end

            if (typeof(deletions)  == RegexMatch)
                statistics["removed_lines"] = statistics["removed_lines"] + parse(Int, deletions[1])
            end

            # 获取文件增减情况
            commit_files_info = _run_git_command(git_path, `show $each_commit --name-status --date=short`)
            for each_line in commit_files_info
                # M = modified
                # A = added
                # D = deleted
                # R = renamed
                # C = copied
                # U = updated but unmerged
                add_match       = match(r"(A)[\s]+",       each_line)
                modified_match  = match(r"(M|R|C|U)[\s]+", each_line)
                delete_match    = match(r"(D)[\s]+",       each_line)
                if typeof(add_match)            == RegexMatch
                    statistics["added_files"]         = statistics["added_files"]    + 1
                elseif typeof(modified_match)   == RegexMatch
                    statistics["modified_files"]      = statistics["modified_files"] + 1
                elseif typeof(delete_match)     == RegexMatch
                    statistics["removed_files"]       = statistics["removed_files"]  + 1
                end
            end
        elseif statistics["commits"] > 0
            # 第二步按照时间顺序进行了排序，所以说如果检测到commit > 0的情况，但时间不匹配，说明不需要继续查找了
            break
        elseif Date(commit_date, DateFormat("y-m-d")) < Date(date, DateFormat("y-m-d"))
            # 如果扫描到的第一个时间就早于设定的时间，说明后面也不可能有匹配的内容，可以直接跳过
            break
        end
    end

    return statistics
end

"""
    _run_git_command(dir::String, command::Cmd)

运行指定的Git命令（必须传入Cmd类型）
"""
function _run_git_command(dir::String, command::Cmd)
    return split(readchomp(`$GIT_COMMAND --git-dir="$(dir).git/" $command`), "\n")

end

function _overprint(str)
    print("\u1b[1F")
    #Moves cursor to beginning of the line n (default 1) lines up
    print(str)   #prints the new line
    print("\u1b[0K")
    # clears  part of the line.
    #If n is 0 (or missing), clear from cursor to the end of the line.
    #If n is 1, clear from cursor to beginning of the line.
    #If n is 2, clear entire line.
    #Cursor position does not change.

    println() #prints a new line, i really don't like this arcane codes
end

# 因为要被makedocs.jl包含，不能在被include的时候执行这一块代码
# 类似Python的if __name__ == "__main__"？
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end

end