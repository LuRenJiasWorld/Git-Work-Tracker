# Git Work Tracker
> 轻松跟踪本地Git仓库的每日活动状态
> 
> Keep tracking of your daily git activity at ease.

> 当前版本只支持简体中文，如果有其他语言需求欢迎[提交Issue](https://github.com/LuRenJiasWorld/Git-Work-Tracker/issues) ！
> 
> Only supports Simplified Chinese now, feel free to [create an issue](https://github.com/LuRenJiasWorld/Git-Work-Tracker/issues) if you need other languages !

## 示例
```bash
julia ./src/Git-Work-Tracker.jl --scan-dir=/Users/lurenjiasworld/Documents/Coding/ --all-branches=true --date=2020-06-04
```

```
你所输入的参数为:
	scan-dir  =>  /Users/lurenjiasworld/Documents/Coding
	date  =>  2020-06-04
	all-branches  =>  true

正在扫描目录/Users/lurenjiasworld/Documents/Coding/源码阅读/MilkyTracker-1.02.00/src/tracker/wince
目录扫描完成，扫描了147462个目录，忽略了126248个目录，扫描到128个Git目录

正在解析仓库128/128：/Users/lurenjiasworld/Documents/Coding/大型项目/Docus/代码/仓库/Doc_Test/

扫描完成！你在2020-06-04的Git活动如下所示:
┌───────────────────┬─────────────────┐
│ Git Opration Type │ Operation Count │
├───────────────────┼─────────────────┤
│           Commits │              15 │
│         Add Lines │             932 │
│      Delete Lines │             329 │
│         Add Files │              10 │
│    Modified Files │              18 │
│     Deleted Files │               1 │
└───────────────────┴─────────────────┘
```

## 运行

> 请确保你安装了最新版本的[Julia](https://julialang.org/downloads/) 环境

```bash
git clone https://github.com/LuRenJiasWorld/Git-Work-Tracker
cd Git-Work-Tracker
julia ./install.jl
julia ./src/Git-Work-Tracker.jl --help
```

## 参数

> 请使用`julia ./src/Git-Work-Tracker.jl --help`查看参数列表

## 开源协议

Apache 2.0 License

