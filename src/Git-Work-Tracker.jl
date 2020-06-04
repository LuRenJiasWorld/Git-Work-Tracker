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

export main, _mount_argparse, _scan_git_repositories, _read_git_repositories

IGNORE_PATH = Set{String}([
    "node_modules",
    "vendor"
])

GIT_COMMAND = `git --no-pager`

"""
    main()

主函数入口，允许如下参数被传入：
1. --scan-dir="/random/dir"     扫描目录，不指定默认为脚本执行的当前目录
2. --all-branches=true/false    是否扫描Git仓库的所有分支，默认为false
3. --date="2020-06-01"          输出某一天的数据，默认为当天
"""
function main()
    # 解析传入参数
    parsed_args = _mount_argparse()
    println("你所输入的参数为:")
    for (arg, val) in parsed_args
        println("\t$arg  =>  $val")
    end

    # 开始扫描
    println("")
    println("开始扫描目录$(parsed_args["scan-dir"]):")
    paths_contains_git_repository = _scan_git_repositories(parsed_args["scan-dir"])

    # 开始解析
    println("")
    println("在目录下扫描到$(length(paths_contains_git_repository))个仓库，开始按照设定的规则进行解析:")
    statistics = _read_git_repositories(paths_contains_git_repository, parsed_args["all-branches"], parsed_args["date"])

    # 输出结果
    println("")
    println("扫描完成！你在$(parsed_args["date"])的Git活动如下所示:")
    pretty_table([
        "Commits"               statistics["commits"];
        "Add Lines"             statistics["add_lines"];
        "Delete Lines"          statistics["remove_lines"];
        "Add Files"             statistics["add_files"];
        "Modified Files"        statistics["modified_files"];
        "Deleted Files"         statistics["remove_files"];
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
    end

    return parse_args(s)
end

"""
    _scan_git_repositories(scan_dir::String)

给定一个目录，自动扫描目录下所有包含`.git`子目录的目录，最后返回一个包含所有『包含Git的目录』的数组
"""
function _scan_git_repositories(scan_dir::String)
    dir_list = Set{String}()

    for (root, dirs, files) in walkdir(scan_dir)
        for dir in dirs
            if occursin(".git", joinpath(root, dir))
                path_contains_git_repository = replace(joinpath(root, dir), r"\.git.*$" => "")
                exclude = false

                for each_ignore_path in IGNORE_PATH
                    if occursin(each_ignore_path, path_contains_git_repository)
                        exclude = true
                        break
                    end
                end

                if exclude == false
                    push!(dir_list, path_contains_git_repository)
                end
            end
        end
    end

    return dir_list
end

"""
    _read_git_repositories(path_list::Set{String},
                           all_branches::Bool,
                           date::String)

根据传入参数读取所有`path_list`中的Git仓库，获得相关统计数据
"""
function _read_git_repositories(path_list::Set{String},
                                all_branches::Bool,
                                date::String)
    statistics = Dict{String, Integer}(
        "add_lines"      =>      0,
        "remove_lines"   =>      0,
        "add_files"      =>      0,
        "modified_files" =>      0,
        "remove_files"   =>      0,
        "commits"        =>      0
    )

    for each_path in path_list
        try
            current_statistics = _read_git_repository(each_path, all_branches, date)

            statistics["add_lines"]       = statistics["add_lines"]       + current_statistics["add_lines"]
            statistics["remove_lines"]    = statistics["remove_lines"]    + current_statistics["remove_lines"]
            statistics["add_files"]       = statistics["add_files"]       + current_statistics["add_files"]
            statistics["modified_files"]  = statistics["modified_files"]  + current_statistics["modified_files"]
            statistics["remove_files"]    = statistics["remove_files"]    + current_statistics["remove_files"]
            statistics["commits"]         = statistics["commits"]         + current_statistics["commits"]
        catch e
            bt = catch_backtrace()
            msg = sprint(showerror, e, bt)
            println("解析$(each_path)时出现错误，错误信息为\n$(msg)")
        end
    end

    return statistics
end

"""
    _read_git_repository(git_path::String,
                         all_branches::Bool,
                         date::String)

读取每个Git仓库中的以下内容：
1. 新增行数
2. 删除行数
3. 新增文件数
4. 删除文件数
5. 提交数
"""
function _read_git_repository(git_path::String,
                              all_branches::Bool,
                              date::String)

    # 1. 分支检查
    branches = Array{String, 1}()
    if all_branches == true
        # 获取所有分支列表
        branch_list_raw = _run_git_command(`branch -a`)
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

    # 2. 获取每个分支中的每个commit编号，因为可能重复，所以要使用Set
    commit_id = Set{String}()
    for each_branch in branches
        commit_log = _run_git_command(`log --first-parent $each_branch`)
        for each_commit_log_line in commit_log
            matched_line = match(r"^commit ([a-z0-9]{40})", each_commit_log_line)
            if typeof(matched_line) == RegexMatch && length(matched_line.offsets) == 1
                push!(commit_id, matched_line[1])
            end
        end
    end

    # 3. 获取每个Commit的信息，将其与date比对，如果比对一致，则解析其中的各项数据
    statistics = Dict{String, Integer}(
        "add_lines"      =>      0,
        "remove_lines"   =>      0,
        "add_files"      =>      0,
        "modified_files" =>      0,
        "remove_files"   =>      0,
        "commits"        =>      length(commit_id)
    )

    for each_commit in commit_id
        commit_patch = _run_git_command(`show $each_commit --date=short`)
        # 检查日期
        commit_date = match(r"Date:[\s]+([0-9]{4}-[0-9]{2}-[0-9]{2})", commit_patch[3])[1]
        if commit_date == date
            # 获取行数增减情况
            commit_lines_info = _run_git_command(`show $each_commit --stat --date=short`)
            last_commit_line_info = commit_lines_info[length(commit_lines_info)]

            insertions = match(r"([\d]+) insertion", last_commit_line_info)
            deletions  = match(r"([\d]+) deletion" , last_commit_line_info)

            if (typeof(insertions) == RegexMatch)
                statistics["add_lines"]     = statistics["add_lines"]    + parse(Int, insertions[1])
            end

            if (typeof(deletions)  == RegexMatch)
                statistics["remove_lines"]  = statistics["remove_lines"] + parse(Int, deletions[1])
            end

            # 获取文件增减情况
            commit_files_info = _run_git_command(`show $each_commit --name-status --date=short`)
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
                    statistics["add_files"]         = statistics["add_files"] + 1
                elseif typeof(modified_match)   == RegexMatch
                    statistics["modified_files"]    = statistics["modified_files"] + 1
                elseif typeof(delete_match)     == RegexMatch
                    statistics["remove_files"]      = statistics["remove_files"] + 1
                end
            end
        end
    end

    return statistics
end

"""
    _run_git_command(command::Cmd)

运行指定的Git命令（必须传入Cmd类型）
"""
function _run_git_command(command::Cmd)
    return split(readchomp(`$GIT_COMMAND $command`), "\n")
end

# 因为要被makedocs.jl包含，不能在被include的时候执行这一块代码
# 类似Python的if __name__ == "__main__"？
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end

end