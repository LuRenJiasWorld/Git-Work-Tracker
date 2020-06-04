push!(LOAD_PATH,"../")
push!(LOAD_PATH,"../src")

include("../src/Git-Work-Tracker.jl")

using Documenter, .GitWorkTracker

makedocs(sitename="Git Work Tracker Documentation", modules = [GitWorkTracker])