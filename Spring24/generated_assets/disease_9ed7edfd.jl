### A Pluto.jl notebook ###
# v0.19.38

#> [frontmatter]
#> chapter = 3
#> section = 1
#> order = 2
#> title = "Spread of Covid19 and the SIR model"
#> layout = "layout.jlhtml"
#> tags = ["diffusion"]
#> description = ""

using Markdown
using InteractiveUtils

# This Pluto notebook uses @bind for interactivity. When running this notebook outside of Pluto, the following 'mock version' of @bind gives bound variables a default value (instead of an error).
macro bind(def, element)
    quote
        local iv = try Base.loaded_modules[Base.PkgId(Base.UUID("6e696c72-6542-2067-7265-42206c756150"), "AbstractPlutoDingetjes")].Bonds.initial_value catch; b -> missing; end
        local el = $(esc(element))
        global $(esc(def)) = Core.applicable(Base.get, el) ? Base.get(el) : iv(el)
        el
    end
end

# ╔═╡ db7eec4a-11b6-42b7-9070-e92500496d74
using CairoMakie.Makie.MathTeXEngine: texfont

# ╔═╡ fdf43912-6623-11eb-2e6a-137c10342f32
using PlutoUI: Slider, TableOfContents, CheckBox, NumberField

# ╔═╡ db08e739-99f2-46a8-80c0-dadd8b2cadd1
using Statistics: mean

# ╔═╡ 2305de0f-79ee-4377-9925-d6f861f2ee86
using GeometryBasics: Point2f0

# ╔═╡ a5c1da76-8cfc-45c0-a2d8-c20e96d78a03
using Graphs#: SimpleGraph, add_edge!, StarGraph, CycleGraph, WheelGraph, betweenness_centrality, eigenvector_centrality, edges, adjacency_matrix, nv, ne

# ╔═╡ ae30a71d-e152-4e2e-900b-76efe94d55cf
using DataFrames#: DataFrame, groupby, rename!, stack, unstack, leftjoin, leftjoin!, Not

# ╔═╡ 642e0095-21f1-444e-a733-1345c7b5e1cc
using DataFrameMacros#: @combine, @transform!, @transform, @groupby, @subset, @subset!

# ╔═╡ 98d4da42-a067-4918-beb0-93147e9f5f7d
using Chain: @chain

# ╔═╡ 5f2782dd-390c-4ebf-8dfe-6b24fdc7c844
using CategoricalArrays: CategoricalArrays, categorical, cut, levels!

# ╔═╡ cf30ace3-1c08-4ef3-8986-a27df7f1799d
using AlgebraOfGraphics, GraphMakie

# ╔═╡ c03fbf6b-436f-4a9b-b0e1-830e1b7849b7
using CairoMakie

# ╔═╡ b6c688d0-5954-4f9b-a559-ad28a585c651
using Makie: Makie,
		Figure, Axis, Legend, Lines,
		lines!, scatter!, scatterlines, scatterlines!, vlines!, 
		hidedecorations!, ylims!, cgrad,
		@lift, Observable

# ╔═╡ 6607dac5-83fa-4d5f-9c8f-8c0c4706d01a
using NetworkLayout: NetworkLayout, Shell

# ╔═╡ e0bfd39a-a5c5-47be-a4f4-ffba3779f8ac
using NearestNeighbors: BallTree, knn

# ╔═╡ c178b435-98ac-4366-b4c9-d57b5be13897
using Distributions: Distributions, LogNormal

# ╔═╡ 54db603a-2751-425d-8e76-b9d0048869bf
using PlutoTest: @test

# ╔═╡ 0e30624c-65fc-11eb-185d-1d018f68f82c
md"""
`disease.jl` | **Version 1.6+** | *last updated: Feb 7, 2024*
"""

# ╔═╡ f4266196-64aa-11eb-3fc1-2bf0e099d19c
md"""
# Diffusion on Networks: Modeling Transmission of Disease

This notebook will be the basis for part of **Lecture 3C** and **Assignment 3**. Here is what we will cover.

1. We will model the diffusion of disease on a network. We will analyze how the parameters of the model change the outcomes.
"""

# ╔═╡ b36832aa-64ab-11eb-308a-8f031686c8d6
md"""
2. We will show how various policies mitigate the spread of the disease. We will see how we can map *social distancing* and *vaccination programs* into the model. 

   The plot below shows how the number of infected people decreases when we randomly pick 20% of the population. *(Can we improve the efficacy of the vaccination program by targeting specific people?)*
"""

# ╔═╡ c8f92204-64ac-11eb-0734-2df58e3373e8
md"""
3. In your assignment you will make to model a little richer by ``(i)`` separating the `R` state into *dead* and *immune* (which includes recovered and vaccinated) and ``(ii)`` taking into account age-specific death (case-fatality) rates.

   *(Can we now improve the efficacy of the vaccination program even more?)*

4. **Is this economics?** Yes and no. There have been many papers studying the economic impact of Covid. Many of them integrate some version of the SIR model into a macroeconomic model.

   If you are interested, you can have a look at the [collection of covid economics resources](https://cepr.org/content/covid-19) by the CEPR, this [blogpost](https://johnhcochrane.blogspot.com/2020/05/an-sir-model-with-behavior.html) by John Cochrane or this [paper](https://www.aeaweb.org/articles?id=10.1257/jep.34.4.105) by an epidemiologist in the *Journal of Economic Perspectives*.

"""

# ╔═╡ 2f9f008a-64aa-11eb-0d9a-0fdfc41d4657
md"""
# The SIR Model

In the simplest case, there are three states.

1. `S`usceptible
2. `I`nfected
3. `R`emoved (recovered or dead)

(For your assignment you will split up the `R` state into immune and dead.)
"""

# ╔═╡ b8d874b6-648d-11eb-251c-636c5ebc1f42
begin
	abstract type State end
	struct S <: State end
	struct I <: State end
	struct R <: State end
	# struct D <: State end # (Assignment)
end

# ╔═╡ f48fa122-649a-11eb-2041-bbf0d0c4670c
const States = Union{subtypes(State)...}

# ╔═╡ 10dd6814-f796-42ea-8d40-287ed7c9d239
md"
## Define the transitions
"

# ╔═╡ 8ddb6f1e-649e-11eb-3982-83d2d319b31f
function transition(::I, par, node, args...; kwargs...)
	(; δ, ρ) = node

	x = rand()
	#= if x < δ # die
		D()
	else=#
	if x < ρ + δ # recover or die
		R()
	else
		I()
	end
end

# ╔═╡ 61a36e78-57f8-4ef0-83b4-90e5952c116f
transition(::R, args...; kwargs...) = R()

# ╔═╡ ffe07e00-0408-4986-9205-0fbb025a698c
function transition(::S, par, node, adjacency_matrix, is_infected)
	(; node_id) = node
	inv_prob = 1.0
	for i in is_infected
	 	inv_prob *= 1 - par.p * adjacency_matrix[i, node_id]
	end
	
	#inv_prob = prod(1 - par.p * adjacency_matrix[i, node_id] for i in is_infected, init = 1.0)
	
	π =	1.0 - inv_prob
	
	rand() < π ? I() : S()
end

# ╔═╡ f4c62f95-876d-4915-8372-258dfde835f7
function iterate!(states_new, states, adjacency_matrix, par, node_df)

	is_infected = findall(isa.(states, I))

	for node_row ∈ eachrow(node_df)
		(; node_id) = node_row
		states_new[node_id] = transition(states[node_id], par, node_row, adjacency_matrix, is_infected)
	end
	
	states_new
end

# ╔═╡ 5d11a2df-3187-4509-ba7b-8388564573a6
function iterate(states, adjacency_matrix, par, node_df)
	states_new = Vector{States}(undef, N)
	iterate!(states_new, states, adjacency_matrix, par, node_df)
	
	states_new
end

# ╔═╡ 50d9fb56-64af-11eb-06b8-eb56903084e2
md"""
## Simulate on a Simple Network

* ``\rho_s``: $(@bind ρ_simple Slider(0.0:0.25:1.0, default = 0.0, show_value =true)) (recovery probability)
* ``\delta_s``: $(@bind δ_simple Slider(0.0:0.25:1.0, default = 0.0, show_value =true)) (death rate)
* ``p_s``: $(@bind p_simple Slider(0.0:0.25:1.0, default = 0.5, show_value =true)) (infection probability)
"""

# ╔═╡ 8d4cb5dc-6573-11eb-29c8-81baa6e3fffc
simple_graph = CycleGraph(10)

# ╔═╡ 6e38d4db-e3ba-4b37-8f3e-c9f9359efa89
T_simple = 15

# ╔═╡ 9302b00c-656f-11eb-25b3-495ae1c843cc
md"""
``t``: $(@bind t0_simple NumberField(1:T_simple, default=1))
"""

# ╔═╡ ce75fe16-6570-11eb-3f3a-577eac7f9ee8
md"""
## Simulate on a Big Network
"""

# ╔═╡ 37972f08-db05-4e84-9528-fe16cd86efbf
md"""
* ``\rho``: $(@bind ρ0 Slider(0.1:0.1:0.9, default = 0.1, show_value =true)) (recovery probability)
* ``\delta``: $(@bind δ0 Slider(0.0:0.02:0.2, default = 0.04, show_value =true)) (death rate)
* ``p``: $(@bind p0 Slider(0.1:0.1:0.9, default = 0.3, show_value =true)) (infection probability)
"""

# ╔═╡ f8bfd21a-60eb-4293-bc66-89b194608be5
T_big = 100

# ╔═╡ 43a25dc8-6574-11eb-3607-311aa8d5451e
period_selector = md"""
``t``: $(@bind t0 NumberField(1:T_big, default=20))
"""

# ╔═╡ f4cd5fb2-6574-11eb-37c4-73d4b21c1883
period_selector

# ╔═╡ 2fd3fa39-5314-443c-a690-bf27de93e479
md"""
# Policies
"""

# ╔═╡ 78e729f8-ac7d-43c5-ad93-c07d9ac7f30e
md"""
## Social Distancing
"""

# ╔═╡ 7b43d3d6-03a0-4e0b-96e2-9de420d3187f
p_range = 0.1:0.1:0.9

# ╔═╡ 65df78ae-1533-4fad-835d-e301581d1c35
md"""
## School closures

__*See [last year's assignment](https://greimel.github.io/networks-course/notebooks_school-closures/)*__
"""

# ╔═╡ 9f040172-36bd-4e46-9827-e25c5c7fba12
md"""
## Vaccinations
"""

# ╔═╡ 34b1a3ba-657d-11eb-17fc-5bf325945dce
md"""
``t``: $(@bind t0_vacc NumberField(1:T_big, default=1))
"""

# ╔═╡ e8b7861e-661c-11eb-1c06-bfedd6ab563f
md"""
It's really hard to see the difference, so let's use an alternative visualization.
"""

# ╔═╡ 79f3c8b7-dea6-473c-87e5-772e391a51f4
md"""
# Assignment 3: Whom to vaccinate?

> If you have 100 doses at your disposal, whom would you vaccinate?
"""

# ╔═╡ 3bf0f92a-991d-42d3-ad30-28fb0acb3269
group_members = ([
	(firstname = "Ella-Louise", lastname = "Flores"),
	(firstname = "Padraig", 	lastname = "Cope"),
	(firstname = "Christy",  	lastname = "Denton")
	]);

# ╔═╡ 1e2189d3-58c5-4f7d-b76c-2e0ad5b7a803
group_number = 99

# ╔═╡ fd20d87b-204d-4f0c-b830-bfbe1b396fcb
if group_number == 99 || (group_members[1].firstname == "Ella-Louise" && group_members[1].lastname == "Flores")
	md"""
!!! danger "Note!"
    **Before you submit**, please replace the randomly generated names [in this cell](#3bf0f92a-991d-42d3-ad30-28fb0acb3269) by the names of your group and put the right group number in [this cell](#1e2189d3-58c5-4f7d-b76c-2e0ad5b7a803).
	"""
end

# ╔═╡ 12d7647e-6a13-11eb-2b1e-9f77bdb3a87a
md"""
## Task 1: Distinguishing `R`ecovered and `D`ead (3 points)
"""

# ╔═╡ 98d449ac-695f-11eb-3daf-dffb377aa5e2
md"""
👉 Add a new state `D`ead.
"""

# ╔═╡ 8a2c223e-6960-11eb-3d8a-516474e6653c
md"""
👉 Add a transition rule for `D`.
"""

# ╔═╡ 809375ba-6960-11eb-29d7-f9ab3ee61367
# transition(::D, args...; kwargs...) = #= your code here =#

# ╔═╡ 945d67f6-6961-11eb-33cf-57ffe340b35f
md"""
👉 Go to section **Define the transtions** and adjust the transition rules for the other states if necessary.
"""

# ╔═╡ 48818cf0-6962-11eb-2024-8fca0690dd78
md"""
Great! You can now have a look how the simulations from the lecture have automatically updated.
"""

# ╔═╡ fac414f6-6961-11eb-03bb-4f58826b0e61
md"""
## Task 2: Introduce age-specific death rates (2 points)

The death probabilities are highly heterogeneous across age groups. See for example [this (_dated_) article in Nature.](https://www.nature.com/articles/s41586-020-2918-0) Let us assume there are the following age groups with age specific $\delta$. *(Feel free to experiment a bit and change how these are computed.)*
"""

# ╔═╡ b92329ed-668d-46b0-9d21-65b04294cf83
md"""
We randomly assign each node into an age bin. This is visualized below.
"""

# ╔═╡ 6b93d1ab-ead5-4d3b-9d19-0d287611fbb6
md"""
We want to adjust the code so that it can handle node-specific $\delta$. The way we are going to do it is to pass a vector $\vec \delta = (\delta_1, \ldots, \delta_N)$ that holds the death probability for each node.

👉 Go the the definition of `transition(::I, ...)`, make sure you understand the code snippet in the comment and uncomment the lines.

"""

# ╔═╡ 1978febe-657c-11eb-04ac-e19b2d0e5a85
md"""
## Task 3: Whom to vaccinate? (5 points)

Can you think of a way to improve the effectiveness of the vaccination program? If you have 100 doses at your disposal, whom would you vaccinate?
"""

# ╔═╡ 18e84a22-69ff-11eb-3909-7fd30fcf3040
function pseudo_random(N, n, offset = 1)
	step = N ÷ n
	range(offset, step = step, length = n)
end

# ╔═╡ 0d2b1bdc-6a14-11eb-340a-3535d7bfbec1
md"""
👉 Decide which nodes you want to vaccinate and adjust the cell below. Make sure you only vaccinate `N_vacc` nodes.
"""

# ╔═╡ 655dcc5d-9b81-4734-ba83-1b0570bed8e4
answer3 = md"""
Your answer

goes here ...
"""

# ╔═╡ 00bd3b6a-19de-4edd-82c3-9c57b4de64f1
md"""
#### Before you submit ...

👉 Make sure you have added your names [in this cell](#3bf0f92a-991d-42d3-ad30-28fb0acb3269) and your group number [in this cell](#1e2189d3-58c5-4f7d-b76c-2e0ad5b7a803).

👉 Make sure that that **all group members proofread** your submission (especially your little essay).

👉 Go to the very top of the notebook and click on the symbol in the very top-right corner. **Export a static html file** of this notebook for submission. In addition, **upload the source code** of the notebook (the .jl file).
"""

# ╔═╡ a81600e1-6b52-460c-808f-a785989bd4a6
md"""
## Appendix to Assignment
"""

# ╔═╡ 515edb16-69f3-11eb-0bc9-a3504565b80b
md"""
### Details on age-specific infection fatality rates
"""

# ╔═╡ deb1435b-6267-40a9-8f94-b3491c0f1c6b
md"""
The death probabilities are highly heterogeneous across age groups. See for example [this article in Nature.](https://www.nature.com/articles/s41586-020-2918-0)

>  We find that age-specific IFRs estimated by the ensemble model range from 0.001% (95% credible interval, 0–0.001) in those aged 5–9 years old (range, 0–0.002% across individual national-level seroprevalence surveys) to 8.29% (95% credible intervals, 7.11–9.59%) in those aged 80+ (range, 2.49–15.55% across individual national-level seroprevalence surveys).

$(Markdown.MD(Markdown.Admonition("danger", "Beware!", [md"These data are outdated."])))

Below find the data from supplementary table S3 from this article.
"""

# ╔═╡ 74c35594-69f0-11eb-015e-2bf4b55e658c
md"""
### Get from infection fatality ratio to $\delta$

When the recovery rate is $\rho$, the expected time infected is $T_I = 1/\rho$. So we want the survival probability to 

$$(1-IFR) = (1 - \delta)^{T_I}.$$ 
"""

# ╔═╡ 6ffb63bc-69f0-11eb-3f84-d3fca5526a3e
get_δ_from_ifr(ifr, ρ) = 1 - (1 - ifr/100)^(ρ)

# ╔═╡ 1b8c26b6-64aa-11eb-2d9a-47db5469a654
md"""
# Appendix
"""

# ╔═╡ 07a66c72-6576-11eb-26f3-810607ca7e51
md"""
## Functions for the simulation
"""

# ╔═╡ ca77fa78-657a-11eb-0faf-15ffd3fdc540
function initial_state(N, infected_nodes, recovered_nodes)
	# fill with "Susceptible"
	init = States[S() for i in 1:N]
	
	init[infected_nodes] .= Ref(I())
	init[recovered_nodes] .= Ref(R())
	
	init
end

# ╔═╡ fecf62c5-2c1d-4709-8c17-d4b6e0565617
function initial_state(N, n_infected)
	
	# spread out the desired number of infected people
	infected_nodes = 1:(N÷n_infected):N
	
	initial_state(N, infected_nodes, [])
end

# ╔═╡ 208445c4-5359-4442-9b9b-bde5e55a8c23
function simulate(
	graph, par, T, 
	init = initial_state(nv(graph), max(nv(graph) ÷ 100, 1)); 
	node_df = DataFrame(; node_id = 1:nv(graph), par...)
)
	mat = adjacency_matrix(graph)
	N = nv(graph)
	
	sim = Matrix{States}(undef, N, T)
	sim[:,1] .= init
	
	for t = 2:T
		iterate!(view(sim, :, t), view(sim, :, t-1), mat, par, node_df)
	end
	sim
end

# ╔═╡ d6694c32-656c-11eb-0796-5f485cccccf0
sim_simple = let
	g = simple_graph
	
	par = (; p = p_simple)
	
	node_df = DataFrame(node_id = 1:nv(g), δ = δ_simple, ρ = ρ_simple)
	@info node_df
	
	sim = simulate(simple_graph, par, T_simple; node_df)

	(; sim, g)
end	

# ╔═╡ e4d016cc-64ae-11eb-1ca2-259e5a262f33
md"""
## Processing the Simulated Data
"""

# ╔═╡ c112f585-489a-4feb-bc12-0122738f9f33
function ordered_states(states)
	levels = unique(states)
	order  = ["S", "I", "R", "D"]
	if levels ⊆ order
		return sorted = order ∩ levels
	else
		return levels
	end
end

# ╔═╡ b0d34450-6497-11eb-01e3-27582a9f1dcc
label(x::DataType) = string(Base.typename(x).name)

# ╔═╡ 63b2882e-649b-11eb-28de-bd418b43a35f
label(x) = label(typeof(x))

# ╔═╡ 11ea4b84-649c-11eb-00a4-d93af0bd31c8
function tidy_simulation_output(sim)
	# go from type to symbol (S() => "S")
	sim1 = label.(sim)
	
	# make it a DataFrame with T columns and N rows
	df0 = DataFrame(sim1, :auto)
	rename!(df0, string.(1:size(df0,2)))
	
	# add a column with node identifier
	df0.node_id = 1:size(df0, 1)
	
	# stack df to
	# node_id | t | state
	df = stack(df0, Not(:node_id), variable_name = :t, value_name = :state)
	# make t numeric
	@transform!(df, :t = parse(Int, eval(:t)),
					 :state = @bycol categorical(:state)
	
				)	
	df
end

# ╔═╡ bf18bef2-649d-11eb-3e3c-45b41a3fa6e5
function fractions_over_time(sim)
	tidy_sim = tidy_simulation_output(sim)
	N, T = size(sim)
	
	return @chain tidy_sim begin
		@groupby(:t, :state)
		@combine(:fraction = length(:node_id) / N)
		# put states into nice order
		@transform(:state = @bycol levels!(:state, ordered_states(:state)))
	end
end

# ╔═╡ 47ac6d3c-6556-11eb-209d-f7a8219512ee
md"""
## Constructing the Figures
"""

# ╔═╡ 5c3a80d2-6db3-4b3b-bc06-55a64e0cac6e
md"""
## Plotting helpers
"""

# ╔═╡ b4707854-88fb-4285-b6b8-6360edd2ccf7
fonts = (regular = texfont(), bold = texfont(:bold), italic = texfont(:italic))

# ╔═╡ 28202f93-8f14-4a54-8389-40093c1fe9cf
figure = (; figurepadding = 3, fonts)

# ╔═╡ f6f71c0e-6553-11eb-1a6a-c96f38c7f17b
function plot_fractions!(figpos, t, sim, color_dict, legpos = nothing)	
	df = fractions_over_time(sim)
			
	plt = data(df) * visual(Lines) * mapping(
		:t => AlgebraOfGraphics.L"t", :fraction, color = :state => ""
	) * visual(Lines)
	
	fg = draw!(figpos, plt, palettes = (; color = collect(color_dict)))

	ax = only(fg).axis
	vlines!(ax, @lift([$t]), color = :gray50, linestyle=(:dash, :loose))	
	ylims!(ax, -0.05, 1.05)

	# some attributes to make the legend nicer
	attr = (orientation = :horizontal, titleposition = :left, framevisible = false)
	
	if !isnothing(legpos)
		leg = legend!(legpos, fg; attr...)
	else
		leg = nothing
	end
 
	(; ax=fg, leg)
end

# ╔═╡ 4a9b5d8a-64b3-11eb-0028-898635af227c
function plot_diffusion!(figpos, graph, sim, t, color_dict; kwargs...)
	sim_colors = [color_dict[label(s)] for s in sim]
	state_as_color_t = @lift(sim_colors[:,$t])
	
    ax = Axis(figpos)

	hidedecorations!(ax)

	N, T = size(sim)
	msize = N < 20 ? 15 : N ≤ 100 ? 10 : 7

	graphplot!(ax, graph;
		node_size  = msize,
		node_color = state_as_color_t,
		kwargs...
	)
	
	ax
end

# ╔═╡ 51a16fcc-6556-11eb-16cc-71a978e02ef0
function sir_plot!(figpos, legpos, sim, graph, t; kwargs...)
				
	states = ordered_states(label.(subtypes(State)))

	colors = Makie.wong_colors()[[5,2,3,1,6,4,7]]
	
	color_dict = Dict(s => colors[i] for (i,s) in enumerate(states))
	
	ax_f, leg = plot_fractions!(figpos[1,2], t, sim, color_dict, legpos)
	ax_d = plot_diffusion!(figpos[1,1], graph, sim, t, color_dict; kwargs...)

	(; ax_f, ax_d, leg)

end 

# ╔═╡ c511f396-6579-11eb-18b1-df745093a116
function compare_sir(sim1, sim2, graph; t=1, kwargs...)
	#t = Observable(1)
		
	fig = Figure(; figure...)
	legpos = fig[1:2,2]
	panel1 = fig[1,1]
	panel2 = fig[2,1]
	
	axs1 = sir_plot!(panel1, legpos,  sim1, graph, t; kwargs...)
	axs2 = sir_plot!(panel2, nothing, sim2, graph, t; kwargs...)
		
	axs1.leg.orientation[] = :vertical	
	
	@assert axes(sim1, 2) == axes(sim2, 2)
	
	(; fig, t, T_range = axes(sim1, 2))
end

# ╔═╡ 67e74a32-6578-11eb-245c-07894c89cc7c
function sir_plot(sim, graph; t=1, kwargs...)
	#t = Observable(1)
	
	fig = Figure(; figure..., size=(600, 300))
	main_fig = fig[2,1]
	leg_pos = fig[1,1]

	sir_plot!(main_fig, leg_pos, sim, graph, t; kwargs...)
	
	(; fig, t, T_range = axes(sim, 2))
	
end

# ╔═╡ 3aeb0106-661b-11eb-362f-6b9af20f71d7
let
	(; sim, g) = sim_simple
	out = sir_plot(sim, g, layout=Shell(), node_attr = (strokewidth=0.5,), ilabels = vertices(g), t=t0_simple)
	out.fig
end

# ╔═╡ e82d5b7f-5f37-4696-9917-58b117b9c1d6
md"
## Spatial graph
"

# ╔═╡ 95b67e4d-5d41-4b86-bb9e-5de97f5d8957
# adapted from David Gleich, Purdue University
# https://www.cs.purdue.edu/homes/dgleich/cs515-2020/julia/viral-spreading.html
function spatial_graph(node_positions; degreedist = LogNormal(log(2),1))
  	n = length(node_positions)
	
	coords_matrix = hcat(Vector.(node_positions)...)
  	T = BallTree(coords_matrix)
	
	g = SimpleGraph(n)
	
	for i = 1:n
		# draw the number of links `deg`
    	deg = min(ceil(Int, rand(degreedist)), n - 1)
    	# use the `deg` closest nodes as neighbours
		idxs, dists = knn(T, coords_matrix[:,i], deg + 1)
    	for j in idxs
      		if i != j
				add_edge!(g, i, j)
      		end
    	end
  	end
	
	g
end

# ╔═╡ c1971734-2299-4038-8bb6-f62d020f92cb
function spatial_graph(N::Int)
	id = 1:N
	x = rand(N)
	y = rand(N)
	node_positions = Point2f0.(x, y)
	
	spatial_graph(node_positions), node_positions
end

# ╔═╡ 0b35f73f-6976-4d85-b61f-b4188440043e
sim_big = let
	par = (; p = p0)
	
	graph, node_positions = spatial_graph(1000)
	node_df = DataFrame(node_id = 1:nv(graph), ρ = ρ0, δ = δ0)

	sim = simulate(graph, par, T_big; node_df)

	sim_big = (; sim, graph, node_positions)
end;

# ╔═╡ 1bd2c660-6572-11eb-268c-732fd2210a58
big_fig = let
	(; sim, graph, node_positions) = sim_big

	attr = (
		layout = _ -> node_positions,
		node_attr  = (; strokewidth = 0.1),
		edge_width = 0.5,
		edge_color = (:black, 0.3),
	)
	
	out = sir_plot(sim, graph; t=t0, attr...)
	out.fig
end

# ╔═╡ 5eafd0f0-6619-11eb-355d-f9de3ae53f6a
big_fig

# ╔═╡ 49b21e4e-6577-11eb-38b2-45d30b0f9c80
graph, node_positions = spatial_graph(1000)

# ╔═╡ c5f48079-f52e-4134-8e6e-6cd4c9ee915d
let
	state = "I"
	fig = Figure(; figure..., size = (400, 300))
	ax = Axis(fig[1,1], 
		title = "#$(state) when varying the infection probability",
		titlefont = :italic
	)

	node_df = DataFrame(node_id = 1:nv(graph), ρ = ρ0, δ = δ0)
	
	for p in p_range
		par = (; p )
		
		sim = simulate(graph, par, 100; node_df)
		
		df0 = fractions_over_time(sim)
		
		filter!(:state => ==(state), df0)
		
		lines!(df0.t, df0.fraction, label = L"p = %$p", color = (:blue, 1 - p))
	end
	Legend(fig[1,2], ax)
	
	fig
end

# ╔═╡ bb924b8e-69f9-11eb-1e4e-7f841ac1c1bd
vacc = let
	N = 1000
	N_vacc = N ÷ 5

	par = (; p = 0.1)
	
	graph, node_positions = spatial_graph(N)
	node_df = DataFrame(node_id = 1:nv(graph), ρ = ρ0, δ = δ0)
	
	vaccinated = [
		"none"   => [],
		"random" => pseudo_random(N, N_vacc, 3),	
		# place for your suggestions
		]
	
	infected_nodes = pseudo_random(N, N ÷ 5, 1)

	sims = map(vaccinated) do (label, vacc_nodes)
		init = initial_state(N, infected_nodes, vacc_nodes)
		
		sim = simulate(graph, par, 100, init; node_df)
		
		label => sim
	end
	
	(; graph, node_positions, sims=sims)
end;

# ╔═╡ 0d610e80-661e-11eb-3b9a-93af6b0ad5de
out_vacc = let
	attr = (
		layout = _ -> vacc.node_positions,
		node_attr  = (; strokewidth = 0.1),
		edge_width = 0.5,
		edge_color = (:black, 0.3),
	)
	
	compare_sir(last.(vacc.sims[[1,2]])..., vacc.graph; t=t0_vacc, attr...)
end;

# ╔═╡ 83b817d2-657d-11eb-3cd2-332a348142ea
out_vacc.fig

# ╔═╡ 02b1e334-661d-11eb-3194-b382045810ef
fig_vaccc = let
	state = "I"
	
	fig = Figure(; figure..., size = (350, 350))
	ax = Axis(fig[1,1], title = "#$(state) when vaccinating different groups")
	
	for (i, (lab, sim)) in enumerate(vacc.sims)
				
		df0 = fractions_over_time(sim)
		
		@subset!(df0, :state == state)
		
		lines!(df0.t, df0.fraction, label = lab)#, color = colors[i])
	end
	
	# some attributes to make the legend nicer
	attr = (orientation = :horizontal, titleposition = :left, framevisible = false)

	leg = Legend(fig[2,1], ax; attr...)

	fig
end

# ╔═╡ 7ed6b942-695f-11eb-38a1-e79655aedfa2
fig_vaccc

# ╔═╡ 5fe4d47c-64b4-11eb-2a44-473ef5b19c6d
md"""
## Utils
"""

# ╔═╡ 66d78eb4-64b4-11eb-2d30-b9cee7370d2a
# generate a list of points that can be used to plot the graph
function edges_as_points(graph, node_positions)
	edges_as_pts = Point2f0[]

	for e in edges(graph)
		push!(edges_as_pts, node_positions[e.src])
        push!(edges_as_pts, node_positions[e.dst])
        push!(edges_as_pts, Point2f0(NaN, NaN))
    end
	
	edges_as_pts
end

# ╔═╡ a81f5244-64aa-11eb-1854-6dbb64c8eb6a
md"""
## Package Environment
"""

# ╔═╡ 5872fda5-148c-4c4d-8127-eb882437c075
md"""
#### Data
"""

# ╔═╡ 159ebefa-49b0-44f6-bb96-5ab816b3fc98
import CSV

# ╔═╡ 1abd6992-6962-11eb-3db0-f3dbe5f095eb
ifr_csv = CSV.File(IOBuffer(
		"""
from	to	IFR_pc
0	4	0.003
5	9	0.001
10	14	0.001
15	19	0.003
20	24	0.006
25	29	0.013
30	34	0.024
35	39	0.040
40	44	0.075
45	49	0.121
50	54	0.207
55	59	0.323
60	64	0.456
65	69	1.075
70	74	1.674
75	79	3.203
80	95	8.292
""" # note: the oldest age group is actually 80+
		));

# ╔═╡ 07c102c2-69ee-11eb-3b29-25e612df6911
ifr_df0 = @chain ifr_csv begin
	DataFrame
	@transform!(
		:age = mean(tuple(:from, :to)),
		:age_bin = @bycol cut(:to, [0, 40, 75, 100])
	)
end

# ╔═╡ 57a72310-69ef-11eb-251b-c5b8ab2c6082
ifr_df = @chain ifr_df0 begin
	groupby(:age_bin)
	@combine(:IFR_pc = mean(:IFR_pc))
	@transform(:age_group = @bycol 1:length(:age_bin))
	@transform(:ρ = 1/7)
	@transform(:δ = get_δ_from_ifr(:IFR_pc, :ρ))
end

# ╔═╡ 29036938-69f4-11eb-09c1-63a7a75de61d
age_graph = let
	N = 1000
	p = 0.5

	node_df = DataFrame(
		node_id = 1:N,
#		ρ = 0.5, δ = 0.01
		age_group = rand(Distributions.Categorical([0.4, 0.35, 0.25]), N)
	)
	@chain node_df begin
		leftjoin!(_, ifr_df, on  = :age_group)
		@transform!(:δ = 20 * :δ)
	end
	
	par = (; p)

	graph, node_positions = spatial_graph(N)
	
	(; par, graph, node_positions, node_df)
end

# ╔═╡ 97b92593-b859-4553-b8d0-a8f3f1445df3
let
	(; graph, node_positions, node_df) = age_graph

	age_groups = unique(node_df.age_bin)
	
	colors = Makie.wong_colors()[[5,2,3,1,6,4,7]]
	color_dict = Dict(s => colors[i] for (i,s) in enumerate(age_groups))

	node_color = [color_dict[grp] for grp ∈ node_df.age_bin]
	fig, ax, _ = graphplot(graph; layout = _ -> node_positions, node_color, figure)

	leg_df = [(; label, element = MarkerElement(; marker=:circle, color)) for (label, color) ∈ pairs(color_dict)] |> DataFrame

	leg_df
	axislegend(ax, leg_df.element, leg_df.label, "age bin")

	fig
end

# ╔═╡ dceb5318-69fc-11eb-2e1b-0b8cef279e05
vacc_age = let
		
	(; par, graph, node_positions, node_df) = age_graph
	N = nv(graph)

	#@info node_df
	
	N_vacc = N ÷ 5

	centr = betweenness_centrality(graph)
	
	split = 50
	vaccinated = [
		"none"    => [],
		"random"  => pseudo_random(N, N_vacc, 4),
		"central 1"=> sortperm(centr, rev=true)[1:N_vacc],
		# place your suggestions here!
		]
	
	infected_nodes = pseudo_random(N, N ÷ 10, 1)
	
	sims = map(vaccinated) do (label, vacc_nodes)
		init = initial_state(N, infected_nodes, vacc_nodes)
		
		sim = simulate(graph, par, 100, init; node_df)
		
		label => sim
	end
	
	(; graph, node_positions, sims=sims)
end;

# ╔═╡ da82d3ea-69f6-11eb-343f-a30cdc36228a
fig_vacc_age = let
	state = @isdefined(D) ? "D" : "I"

	fig = Figure(; figure..., size = (350, 300))
	ax = Axis(fig[1,1], 
		title = "#$(state) when vaccinating different groups",
		titlefont = :italic
	)

	for (i, (lab, sim)) in enumerate(vacc_age.sims)
				
		df0 = fractions_over_time(sim)
		
		filter!(:state => ==(state), df0)
		
		lines!(df0.t, df0.fraction, label = lab)
	end
	
	axislegend(ax)

	fig
end

# ╔═╡ d18f1b0c-69ee-11eb-2fc0-4f14873847fb
scatterlines(ifr_df0.age, ifr_df0.IFR_pc, 
			 axis = (xlabel="age group", ylabel = "infection fatality ratio (%)")
			)

# ╔═╡ 7f57095f-88c5-4d65-b758-3bc928ea8d76
md"""
#### Plotting
"""

# ╔═╡ 17989c8e-ff35-4900-bb0c-63298a87e3fb
md"""
#### Spatial network
"""

# ╔═╡ bed07322-64b1-11eb-3324-7b7ac5e8fba2
md"""
## Other Stuff
"""

# ╔═╡ 31bbc540-68cd-4d4a-b87a-d648e003524c
TableOfContents()

# ╔═╡ 21dfdec3-db5f-40d7-a59e-b1c323a69fc8
begin
	hint(text) = Markdown.MD(Markdown.Admonition("hint", "Hint", [text]))
	almost(text) = Markdown.MD(Markdown.Admonition("warning", "Almost there!", [text]))
	still_missing(text=md"Replace `missing` with your answer.") = Markdown.MD(Markdown.Admonition("warning", "Here we go!", [text]))
	keep_working(text=md"The answer is not quite right.") = Markdown.MD(Markdown.Admonition("danger", "Keep working on it!", [text]))
	yays = [md"Great!", md"Yay ❤", md"Great! 🎉", md"Well done!", md"Keep it up!", md"Good job!", md"Awesome!", md"You got the right answer!", md"Let's move on to the next section."]
	correct(text=rand(yays)) = Markdown.MD(Markdown.Admonition("correct", "Got it!", [text]))
end

# ╔═╡ b9c7df54-6a0c-11eb-1982-d7157b2c5b92
if @isdefined D
	if hasproperty(States.b.b, :b)
		correct(md"You've successfully defined type `D`.")
	else
		almost(md"You've successfully defined `D`. But you need to do it in the right place. [Go to **The SIR Model**](#b8d874b6-648d-11eb-251c-636c5ebc1f42) and uncomment the line that defines `D`.")
	end
else
	keep_working(md"[Go to **The SIR Model**](#b8d874b6-648d-11eb-251c-636c5ebc1f42) and uncomment the line that defines `D`.")
end

# ╔═╡ dc9ac0c0-6a0a-11eb-2ca8-ada347bffa85
try
	transition(D())
	if transition(D()) == D()
		correct(md"You've successfully specified the transition rule for `D`.")
	else
		keey_working(md"The transition rule for `D` doesn't seem to work correctly")
	end
catch e
	if e isa MethodError
		keep_working(md"The transition rule for `D` is not yet defined.")
	else
		keep_working(md"The transition rule for `D` doesn't seem to work correctly")
	end
end

# ╔═╡ 1be1ac8a-6961-11eb-2736-79c77025255d
hint(md"You can look at the section **Define the transitions** for inspiration.")

# ╔═╡ 11c507a2-6a0f-11eb-35bf-55e1116a3c72
begin
	try
		test1 = transition(I(), (;), (δ = 1, ρ = 0), 0) == D()
		test2 = transition(I(), (;), (δ = 0, ρ = 1), 0) == R()
		test3 = transition(I(), (;), (δ = 0, ρ = 0), 0) == I()
	
		if test1 && test2 && test3
			correct(md"It seems that you've successfully adjusted the transition rule for `I`. *(Note: the other rules are not checked)*")
		else
			keep_working()
		end
	catch
		keep_working()
	end
end

# ╔═╡ ff0608aa-4653-430c-a050-f7a987c5d520
function wordcount(text)
	stripped_text = strip(replace(string(text), r"\s" => " "))
   	words = split(stripped_text, (' ', '-', '.', ',', ':', '_', '"', ';', '!', '\''))
   	length(filter(!=(""), words))
end

# ╔═╡ d994b4c2-0e64-4d4b-b526-a876b4e0b0e3
@test wordcount("  Hello,---it's me.  ") == 4

# ╔═╡ 5cc16d98-a809-4276-8b17-2e858e8ec42a
@test wordcount("This;doesn't really matter.") == 5

# ╔═╡ 259a640c-73cf-4694-8bd2-da3f4dbdb2ce
show_words(answer) = md"_approximately $(wordcount(answer)) words_"

# ╔═╡ 989dd65c-c598-4dfc-9099-6f986847aa52
function show_words_limit(answer, limit)
	count = wordcount(answer)
	if count < 1.02 * limit
		return show_words(answer)
	else
		return almost(md"You are at $count words. Please shorten your text a bit, to get **below $limit words**.")
	end
end

# ╔═╡ 3c83862c-3603-4f85-9a57-89e662b250df
limit3 = 300; show_words_limit(answer3, limit3)

# ╔═╡ eacde133-b154-4a09-b582-84d59dda3984
md"""
Now write a short essay describing your choice. *(Your simulation results are subject to random noise. Make sure you run you simulations multiple times to make sure they are robust.)*

👉 Describe how you would select nodes to be vaccinated

👉 Be accurate but concise. Aim at no more than $limit3 words.
"""

# ╔═╡ 7740e8e6-2063-4d9d-9c07-b7c164cf3310
members = let
	names = map(group_members) do (; firstname, lastname)
		firstname * " " * lastname
	end
	join(names, ", ", " & ")
end

# ╔═╡ 1f53eee1-c160-468f-93b3-d43a87a863ec
md"""
*submitted by* **$members** (*group $(group_number)*)
"""

# ╔═╡ 96f5a53b-72ab-44db-b8f3-37ceb802bf1a
md"""
## Acknowledgement
"""

# ╔═╡ 7e754b5f-0078-43e7-b0ca-eaef2fcf3e53
Markdown.MD(
	Markdown.Admonition("warning", "The design of this notebook is based on", 
[md"""
		
_**Computational Thinking**, a live online Julia/Pluto textbook._ [(computationalthinking.mit.edu)](https://computationalthinking.mit.edu)
"""]
	))

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
AlgebraOfGraphics = "cbdf2221-f076-402e-a563-3d30da359d67"
CSV = "336ed68f-0bac-5ca0-87d4-7b16caf5d00b"
CairoMakie = "13f3f980-e62b-5c42-98c6-ff1f3baf88f0"
CategoricalArrays = "324d7699-5711-5eae-9e2f-1d82baa6b597"
Chain = "8be319e6-bccf-4806-a6f7-6fae938471bc"
DataFrameMacros = "75880514-38bc-4a95-a458-c2aea5a3a702"
DataFrames = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
Distributions = "31c24e10-a181-5473-b8eb-7969acd0382f"
GeometryBasics = "5c1252a2-5f33-56bf-86c9-59e7332b4326"
GraphMakie = "1ecd5474-83a3-4783-bb4f-06765db800d2"
Graphs = "86223c79-3864-5bf0-83f7-82e725a168b6"
Makie = "ee78f7c6-11fb-53f2-987a-cfe4a2b5a57a"
NearestNeighbors = "b8a86587-4115-5ab1-83bc-aa920d37bbce"
NetworkLayout = "46757867-2c16-5918-afeb-47bfcb05e46a"
PlutoTest = "cb4044da-4d16-4ffa-a6a3-8cad7f73ebdc"
PlutoUI = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
Statistics = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"

[compat]
AlgebraOfGraphics = "~0.6.18"
CSV = "~0.10.12"
CairoMakie = "~0.11.8"
CategoricalArrays = "~0.10.8"
Chain = "~0.5.0"
DataFrameMacros = "~0.4.1"
DataFrames = "~1.6.1"
Distributions = "~0.25.107"
GeometryBasics = "~0.4.10"
GraphMakie = "~0.5.9"
Graphs = "~1.9.0"
Makie = "~0.20.7"
NearestNeighbors = "~0.4.16"
NetworkLayout = "~0.4.6"
PlutoTest = "~0.2.2"
PlutoUI = "~0.7.55"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.10.0"
manifest_format = "2.0"
project_hash = "7c7a088aca3870c87399236ef45bdd199bba77ab"

[[deps.AbstractFFTs]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "d92ad398961a3ed262d8bf04a1a2b8340f915fef"
uuid = "621f4979-c628-5d54-868e-fcf4e3e8185c"
version = "1.5.0"
weakdeps = ["ChainRulesCore", "Test"]

    [deps.AbstractFFTs.extensions]
    AbstractFFTsChainRulesCoreExt = "ChainRulesCore"
    AbstractFFTsTestExt = "Test"

[[deps.AbstractLattices]]
git-tree-sha1 = "222ee9e50b98f51b5d78feb93dd928880df35f06"
uuid = "398f06c4-4d28-53ec-89ca-5b2656b7603d"
version = "0.3.0"

[[deps.AbstractPlutoDingetjes]]
deps = ["Pkg"]
git-tree-sha1 = "c278dfab760520b8bb7e9511b968bf4ba38b7acc"
uuid = "6e696c72-6542-2067-7265-42206c756150"
version = "1.2.3"

[[deps.AbstractTrees]]
git-tree-sha1 = "faa260e4cb5aba097a73fab382dd4b5819d8ec8c"
uuid = "1520ce14-60c1-5f80-bbc7-55ef81b5835c"
version = "0.4.4"

[[deps.Adapt]]
deps = ["LinearAlgebra", "Requires"]
git-tree-sha1 = "0fb305e0253fd4e833d486914367a2ee2c2e78d0"
uuid = "79e6a3ab-5dfb-504d-930d-738a2a938a0e"
version = "4.0.1"
weakdeps = ["StaticArrays"]

    [deps.Adapt.extensions]
    AdaptStaticArraysExt = "StaticArrays"

[[deps.AlgebraOfGraphics]]
deps = ["Colors", "Dates", "Dictionaries", "FileIO", "GLM", "GeoInterface", "GeometryBasics", "GridLayoutBase", "KernelDensity", "Loess", "Makie", "PlotUtils", "PooledArrays", "PrecompileTools", "RelocatableFolders", "StatsBase", "StructArrays", "Tables"]
git-tree-sha1 = "3fbdee81b0cdc2b106b681dd2b9d4bdc60ca35a2"
uuid = "cbdf2221-f076-402e-a563-3d30da359d67"
version = "0.6.18"

[[deps.Animations]]
deps = ["Colors"]
git-tree-sha1 = "e81c509d2c8e49592413bfb0bb3b08150056c79d"
uuid = "27a7e980-b3e6-11e9-2bcd-0b925532e340"
version = "0.4.1"

[[deps.ArgTools]]
uuid = "0dad84c5-d112-42e6-8d28-ef12dabb789f"
version = "1.1.1"

[[deps.ArnoldiMethod]]
deps = ["LinearAlgebra", "Random", "StaticArrays"]
git-tree-sha1 = "62e51b39331de8911e4a7ff6f5aaf38a5f4cc0ae"
uuid = "ec485272-7323-5ecc-a04f-4719b315124d"
version = "0.2.0"

[[deps.ArrayInterface]]
deps = ["Adapt", "LinearAlgebra", "Requires", "SparseArrays", "SuiteSparse"]
git-tree-sha1 = "bbec08a37f8722786d87bedf84eae19c020c4efa"
uuid = "4fba245c-0d91-5ea0-9b3e-6abc04ee57a9"
version = "7.7.0"

    [deps.ArrayInterface.extensions]
    ArrayInterfaceBandedMatricesExt = "BandedMatrices"
    ArrayInterfaceBlockBandedMatricesExt = "BlockBandedMatrices"
    ArrayInterfaceCUDAExt = "CUDA"
    ArrayInterfaceGPUArraysCoreExt = "GPUArraysCore"
    ArrayInterfaceStaticArraysCoreExt = "StaticArraysCore"
    ArrayInterfaceTrackerExt = "Tracker"

    [deps.ArrayInterface.weakdeps]
    BandedMatrices = "aae01518-5342-5314-be14-df237901396f"
    BlockBandedMatrices = "ffab5731-97b5-5995-9138-79e8c1846df0"
    CUDA = "052768ef-5323-5732-b1bb-66c8b64840ba"
    GPUArraysCore = "46192b85-c4d5-4398-a991-12ede77f4527"
    StaticArraysCore = "1e83bf80-4336-4d27-bf5d-d5a4f845583c"
    Tracker = "9f7883ad-71c0-57eb-9f7f-b5c9e6d3789c"

[[deps.Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"

[[deps.Automa]]
deps = ["PrecompileTools", "TranscodingStreams"]
git-tree-sha1 = "588e0d680ad1d7201d4c6a804dcb1cd9cba79fbb"
uuid = "67c07d97-cdcb-5c2c-af73-a7f9c32a568b"
version = "1.0.3"

[[deps.AxisAlgorithms]]
deps = ["LinearAlgebra", "Random", "SparseArrays", "WoodburyMatrices"]
git-tree-sha1 = "01b8ccb13d68535d73d2b0c23e39bd23155fb712"
uuid = "13072b0f-2c55-5437-9ae7-d433b7a33950"
version = "1.1.0"

[[deps.AxisArrays]]
deps = ["Dates", "IntervalSets", "IterTools", "RangeArrays"]
git-tree-sha1 = "16351be62963a67ac4083f748fdb3cca58bfd52f"
uuid = "39de3d68-74b9-583c-8d2d-e117c070f3a9"
version = "0.4.7"

[[deps.Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"

[[deps.BenchmarkTools]]
deps = ["JSON", "Logging", "Printf", "Profile", "Statistics", "UUIDs"]
git-tree-sha1 = "f1f03a9fa24271160ed7e73051fba3c1a759b53f"
uuid = "6e4b80f9-dd63-53aa-95a3-0cdb28fa8baf"
version = "1.4.0"

[[deps.Bzip2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "9e2a6b69137e6969bab0152632dcb3bc108c8bdd"
uuid = "6e34b625-4abd-537c-b88f-471c36dfa7a0"
version = "1.0.8+1"

[[deps.CEnum]]
git-tree-sha1 = "389ad5c84de1ae7cf0e28e381131c98ea87d54fc"
uuid = "fa961155-64e5-5f13-b03f-caf6b980ea82"
version = "0.5.0"

[[deps.CRC32c]]
uuid = "8bf52ea8-c179-5cab-976a-9e18b702a9bc"

[[deps.CRlibm]]
deps = ["CRlibm_jll"]
git-tree-sha1 = "32abd86e3c2025db5172aa182b982debed519834"
uuid = "96374032-68de-5a5b-8d9e-752f78720389"
version = "1.0.1"

[[deps.CRlibm_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "e329286945d0cfc04456972ea732551869af1cfc"
uuid = "4e9b3aee-d8a1-5a3d-ad8b-7d824db253f0"
version = "1.0.1+0"

[[deps.CSV]]
deps = ["CodecZlib", "Dates", "FilePathsBase", "InlineStrings", "Mmap", "Parsers", "PooledArrays", "PrecompileTools", "SentinelArrays", "Tables", "Unicode", "WeakRefStrings", "WorkerUtilities"]
git-tree-sha1 = "679e69c611fff422038e9e21e270c4197d49d918"
uuid = "336ed68f-0bac-5ca0-87d4-7b16caf5d00b"
version = "0.10.12"

[[deps.Cairo]]
deps = ["Cairo_jll", "Colors", "Glib_jll", "Graphics", "Libdl", "Pango_jll"]
git-tree-sha1 = "d0b3f8b4ad16cb0a2988c6788646a5e6a17b6b1b"
uuid = "159f3aea-2a34-519c-b102-8c37f9878175"
version = "1.0.5"

[[deps.CairoMakie]]
deps = ["CRC32c", "Cairo", "Colors", "FFTW", "FileIO", "FreeType", "GeometryBasics", "LinearAlgebra", "Makie", "PrecompileTools"]
git-tree-sha1 = "a80d49ed3333f5f78df8ffe76d07e88cc35e9172"
uuid = "13f3f980-e62b-5c42-98c6-ff1f3baf88f0"
version = "0.11.8"

[[deps.Cairo_jll]]
deps = ["Artifacts", "Bzip2_jll", "CompilerSupportLibraries_jll", "Fontconfig_jll", "FreeType2_jll", "Glib_jll", "JLLWrappers", "LZO_jll", "Libdl", "Pixman_jll", "Pkg", "Xorg_libXext_jll", "Xorg_libXrender_jll", "Zlib_jll", "libpng_jll"]
git-tree-sha1 = "4b859a208b2397a7a623a03449e4636bdb17bcf2"
uuid = "83423d85-b0ee-5818-9007-b63ccbeb887a"
version = "1.16.1+1"

[[deps.Calculus]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "f641eb0a4f00c343bbc32346e1217b86f3ce9dad"
uuid = "49dc2e85-a5d0-5ad3-a950-438e2897f1b9"
version = "0.5.1"

[[deps.CategoricalArrays]]
deps = ["DataAPI", "Future", "Missings", "Printf", "Requires", "Statistics", "Unicode"]
git-tree-sha1 = "1568b28f91293458345dabba6a5ea3f183250a61"
uuid = "324d7699-5711-5eae-9e2f-1d82baa6b597"
version = "0.10.8"

    [deps.CategoricalArrays.extensions]
    CategoricalArraysJSONExt = "JSON"
    CategoricalArraysRecipesBaseExt = "RecipesBase"
    CategoricalArraysSentinelArraysExt = "SentinelArrays"
    CategoricalArraysStructTypesExt = "StructTypes"

    [deps.CategoricalArrays.weakdeps]
    JSON = "682c06a0-de6a-54ab-a142-c8b1cf79cde6"
    RecipesBase = "3cdcf5f2-1ef4-517c-9805-6587b60abb01"
    SentinelArrays = "91c51154-3ec4-41a3-a24f-3f23e20d615c"
    StructTypes = "856f2bd8-1eba-4b0a-8007-ebc267875bd4"

[[deps.Chain]]
git-tree-sha1 = "8c4920235f6c561e401dfe569beb8b924adad003"
uuid = "8be319e6-bccf-4806-a6f7-6fae938471bc"
version = "0.5.0"

[[deps.ChainRulesCore]]
deps = ["Compat", "LinearAlgebra"]
git-tree-sha1 = "ab79d1f9754a3988a7792caec43bfdc03996020f"
uuid = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
version = "1.21.0"
weakdeps = ["SparseArrays"]

    [deps.ChainRulesCore.extensions]
    ChainRulesCoreSparseArraysExt = "SparseArrays"

[[deps.CodecBzip2]]
deps = ["Bzip2_jll", "Libdl", "TranscodingStreams"]
git-tree-sha1 = "9b1ca1aa6ce3f71b3d1840c538a8210a043625eb"
uuid = "523fee87-0ab8-5b00-afb7-3ecf72e48cfd"
version = "0.8.2"

[[deps.CodecZlib]]
deps = ["TranscodingStreams", "Zlib_jll"]
git-tree-sha1 = "59939d8a997469ee05c4b4944560a820f9ba0d73"
uuid = "944b1d66-785c-5afd-91f1-9de20f533193"
version = "0.7.4"

[[deps.ColorBrewer]]
deps = ["Colors", "JSON", "Test"]
git-tree-sha1 = "61c5334f33d91e570e1d0c3eb5465835242582c4"
uuid = "a2cac450-b92f-5266-8821-25eda20663c8"
version = "0.4.0"

[[deps.ColorSchemes]]
deps = ["ColorTypes", "ColorVectorSpace", "Colors", "FixedPointNumbers", "PrecompileTools", "Random"]
git-tree-sha1 = "67c1f244b991cad9b0aa4b7540fb758c2488b129"
uuid = "35d6a980-a343-548e-a6ea-1d62b119f2f4"
version = "3.24.0"

[[deps.ColorTypes]]
deps = ["FixedPointNumbers", "Random"]
git-tree-sha1 = "eb7f0f8307f71fac7c606984ea5fb2817275d6e4"
uuid = "3da002f7-5984-5a60-b8a6-cbb66c0b333f"
version = "0.11.4"

[[deps.ColorVectorSpace]]
deps = ["ColorTypes", "FixedPointNumbers", "LinearAlgebra", "Requires", "Statistics", "TensorCore"]
git-tree-sha1 = "a1f44953f2382ebb937d60dafbe2deea4bd23249"
uuid = "c3611d14-8923-5661-9e6a-0046d554d3a4"
version = "0.10.0"
weakdeps = ["SpecialFunctions"]

    [deps.ColorVectorSpace.extensions]
    SpecialFunctionsExt = "SpecialFunctions"

[[deps.Colors]]
deps = ["ColorTypes", "FixedPointNumbers", "Reexport"]
git-tree-sha1 = "fc08e5930ee9a4e03f84bfb5211cb54e7769758a"
uuid = "5ae59095-9a9b-59fe-a467-6f913c188581"
version = "0.12.10"

[[deps.Combinatorics]]
git-tree-sha1 = "08c8b6831dc00bfea825826be0bc8336fc369860"
uuid = "861a8166-3701-5b0c-9a16-15d98fcdc6aa"
version = "1.0.2"

[[deps.CommonSubexpressions]]
deps = ["MacroTools", "Test"]
git-tree-sha1 = "7b8a93dba8af7e3b42fecabf646260105ac373f7"
uuid = "bbf7d656-a473-5ed7-a52c-81e309532950"
version = "0.3.0"

[[deps.Compat]]
deps = ["TOML", "UUIDs"]
git-tree-sha1 = "75bd5b6fc5089df449b5d35fa501c846c9b6549b"
uuid = "34da2185-b29b-5c13-b0c7-acf172513d20"
version = "4.12.0"
weakdeps = ["Dates", "LinearAlgebra"]

    [deps.Compat.extensions]
    CompatLinearAlgebraExt = "LinearAlgebra"

[[deps.CompilerSupportLibraries_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "e66e0078-7015-5450-92f7-15fbd957f2ae"
version = "1.0.5+1"

[[deps.ConstructionBase]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "c53fc348ca4d40d7b371e71fd52251839080cbc9"
uuid = "187b0558-2788-49d3-abe0-74a17ed4e7c9"
version = "1.5.4"
weakdeps = ["IntervalSets", "StaticArrays"]

    [deps.ConstructionBase.extensions]
    ConstructionBaseIntervalSetsExt = "IntervalSets"
    ConstructionBaseStaticArraysExt = "StaticArrays"

[[deps.Contour]]
git-tree-sha1 = "d05d9e7b7aedff4e5b51a029dced05cfb6125781"
uuid = "d38c429a-6771-53c6-b99e-75d170b6e991"
version = "0.6.2"

[[deps.Crayons]]
git-tree-sha1 = "249fe38abf76d48563e2f4556bebd215aa317e15"
uuid = "a8cc5b0e-0ffa-5ad4-8c14-923d3ee1735f"
version = "4.1.1"

[[deps.DataAPI]]
git-tree-sha1 = "abe83f3a2f1b857aac70ef8b269080af17764bbe"
uuid = "9a962f9c-6df0-11e9-0e5d-c546b8b5ee8a"
version = "1.16.0"

[[deps.DataFrameMacros]]
deps = ["DataFrames", "MacroTools"]
git-tree-sha1 = "5275530d05af21f7778e3ef8f167fb493999eea1"
uuid = "75880514-38bc-4a95-a458-c2aea5a3a702"
version = "0.4.1"

[[deps.DataFrames]]
deps = ["Compat", "DataAPI", "DataStructures", "Future", "InlineStrings", "InvertedIndices", "IteratorInterfaceExtensions", "LinearAlgebra", "Markdown", "Missings", "PooledArrays", "PrecompileTools", "PrettyTables", "Printf", "REPL", "Random", "Reexport", "SentinelArrays", "SortingAlgorithms", "Statistics", "TableTraits", "Tables", "Unicode"]
git-tree-sha1 = "04c738083f29f86e62c8afc341f0967d8717bdb8"
uuid = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
version = "1.6.1"

[[deps.DataStructures]]
deps = ["Compat", "InteractiveUtils", "OrderedCollections"]
git-tree-sha1 = "ac67408d9ddf207de5cfa9a97e114352430f01ed"
uuid = "864edb3b-99cc-5e75-8d2d-829cb0a9cfe8"
version = "0.18.16"

[[deps.DataValueInterfaces]]
git-tree-sha1 = "bfc1187b79289637fa0ef6d4436ebdfe6905cbd6"
uuid = "e2d170a0-9d28-54be-80f0-106bbe20a464"
version = "1.0.0"

[[deps.Dates]]
deps = ["Printf"]
uuid = "ade2ca70-3891-5945-98fb-dc099432e06a"

[[deps.DelaunayTriangulation]]
deps = ["DataStructures", "EnumX", "ExactPredicates", "Random", "SimpleGraphs"]
git-tree-sha1 = "d4e9dc4c6106b8d44e40cd4faf8261a678552c7c"
uuid = "927a84f5-c5f4-47a5-9785-b46e178433df"
version = "0.8.12"

[[deps.Dictionaries]]
deps = ["Indexing", "Random", "Serialization"]
git-tree-sha1 = "1f3b7b0d321641c1f2e519f7aed77f8e1f6cb133"
uuid = "85a47980-9c8c-11e8-2b9f-f7ca1fa99fb4"
version = "0.3.29"

[[deps.DiffResults]]
deps = ["StaticArraysCore"]
git-tree-sha1 = "782dd5f4561f5d267313f23853baaaa4c52ea621"
uuid = "163ba53b-c6d8-5494-b064-1a9d43ac40c5"
version = "1.1.0"

[[deps.DiffRules]]
deps = ["IrrationalConstants", "LogExpFunctions", "NaNMath", "Random", "SpecialFunctions"]
git-tree-sha1 = "23163d55f885173722d1e4cf0f6110cdbaf7e272"
uuid = "b552c78f-8df3-52c6-915a-8e097449b14b"
version = "1.15.1"

[[deps.Distances]]
deps = ["LinearAlgebra", "Statistics", "StatsAPI"]
git-tree-sha1 = "66c4c81f259586e8f002eacebc177e1fb06363b0"
uuid = "b4f34e82-e78d-54a5-968a-f98e89d6e8f7"
version = "0.10.11"
weakdeps = ["ChainRulesCore", "SparseArrays"]

    [deps.Distances.extensions]
    DistancesChainRulesCoreExt = "ChainRulesCore"
    DistancesSparseArraysExt = "SparseArrays"

[[deps.Distributed]]
deps = ["Random", "Serialization", "Sockets"]
uuid = "8ba89e20-285c-5b6f-9357-94700520ee1b"

[[deps.Distributions]]
deps = ["FillArrays", "LinearAlgebra", "PDMats", "Printf", "QuadGK", "Random", "SpecialFunctions", "Statistics", "StatsAPI", "StatsBase", "StatsFuns"]
git-tree-sha1 = "7c302d7a5fec5214eb8a5a4c466dcf7a51fcf169"
uuid = "31c24e10-a181-5473-b8eb-7969acd0382f"
version = "0.25.107"

    [deps.Distributions.extensions]
    DistributionsChainRulesCoreExt = "ChainRulesCore"
    DistributionsDensityInterfaceExt = "DensityInterface"
    DistributionsTestExt = "Test"

    [deps.Distributions.weakdeps]
    ChainRulesCore = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
    DensityInterface = "b429d917-457f-4dbc-8f4c-0cc954292b1d"
    Test = "8dfed614-e22c-5e08-85e1-65c5234f0b40"

[[deps.DocStringExtensions]]
deps = ["LibGit2"]
git-tree-sha1 = "2fb1e02f2b635d0845df5d7c167fec4dd739b00d"
uuid = "ffbed154-4ef7-542d-bbb7-c09d3a79fcae"
version = "0.9.3"

[[deps.Downloads]]
deps = ["ArgTools", "FileWatching", "LibCURL", "NetworkOptions"]
uuid = "f43a241f-c20a-4ad4-852c-f6b1247861c6"
version = "1.6.0"

[[deps.DualNumbers]]
deps = ["Calculus", "NaNMath", "SpecialFunctions"]
git-tree-sha1 = "5837a837389fccf076445fce071c8ddaea35a566"
uuid = "fa6b7ba4-c1ee-5f82-b5fc-ecf0adba8f74"
version = "0.6.8"

[[deps.EarCut_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "e3290f2d49e661fbd94046d7e3726ffcb2d41053"
uuid = "5ae413db-bbd1-5e63-b57d-d24a61df00f5"
version = "2.2.4+0"

[[deps.EnumX]]
git-tree-sha1 = "bdb1942cd4c45e3c678fd11569d5cccd80976237"
uuid = "4e289a0a-7415-4d19-859d-a7e5c4648b56"
version = "1.0.4"

[[deps.ExactPredicates]]
deps = ["IntervalArithmetic", "Random", "StaticArrays"]
git-tree-sha1 = "b3f2ff58735b5f024c392fde763f29b057e4b025"
uuid = "429591f6-91af-11e9-00e2-59fbe8cec110"
version = "2.2.8"

[[deps.Expat_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "4558ab818dcceaab612d1bb8c19cee87eda2b83c"
uuid = "2e619515-83b5-522b-bb60-26c02a35a201"
version = "2.5.0+0"

[[deps.Extents]]
git-tree-sha1 = "2140cd04483da90b2da7f99b2add0750504fc39c"
uuid = "411431e0-e8b7-467b-b5e0-f676ba4f2910"
version = "0.1.2"

[[deps.FFMPEG_jll]]
deps = ["Artifacts", "Bzip2_jll", "FreeType2_jll", "FriBidi_jll", "JLLWrappers", "LAME_jll", "Libdl", "Ogg_jll", "OpenSSL_jll", "Opus_jll", "PCRE2_jll", "Zlib_jll", "libaom_jll", "libass_jll", "libfdk_aac_jll", "libvorbis_jll", "x264_jll", "x265_jll"]
git-tree-sha1 = "466d45dc38e15794ec7d5d63ec03d776a9aff36e"
uuid = "b22a6f82-2f65-5046-a5b2-351ab43fb4e5"
version = "4.4.4+1"

[[deps.FFTW]]
deps = ["AbstractFFTs", "FFTW_jll", "LinearAlgebra", "MKL_jll", "Preferences", "Reexport"]
git-tree-sha1 = "4820348781ae578893311153d69049a93d05f39d"
uuid = "7a1cc6ca-52ef-59f5-83cd-3a7055c09341"
version = "1.8.0"

[[deps.FFTW_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "c6033cc3892d0ef5bb9cd29b7f2f0331ea5184ea"
uuid = "f5851436-0d7a-5f13-b9de-f02708fd171a"
version = "3.3.10+0"

[[deps.FileIO]]
deps = ["Pkg", "Requires", "UUIDs"]
git-tree-sha1 = "c5c28c245101bd59154f649e19b038d15901b5dc"
uuid = "5789e2e9-d7fb-5bc7-8068-2c6fae9b9549"
version = "1.16.2"

[[deps.FilePaths]]
deps = ["FilePathsBase", "MacroTools", "Reexport", "Requires"]
git-tree-sha1 = "919d9412dbf53a2e6fe74af62a73ceed0bce0629"
uuid = "8fc22ac5-c921-52a6-82fd-178b2807b824"
version = "0.8.3"

[[deps.FilePathsBase]]
deps = ["Compat", "Dates", "Mmap", "Printf", "Test", "UUIDs"]
git-tree-sha1 = "9f00e42f8d99fdde64d40c8ea5d14269a2e2c1aa"
uuid = "48062228-2e41-5def-b9a4-89aafe57970f"
version = "0.9.21"

[[deps.FileWatching]]
uuid = "7b1f6079-737a-58dc-b8bc-7a2ca5c1b5ee"

[[deps.FillArrays]]
deps = ["LinearAlgebra", "Random"]
git-tree-sha1 = "5b93957f6dcd33fc343044af3d48c215be2562f1"
uuid = "1a297f60-69ca-5386-bcde-b61e274b549b"
version = "1.9.3"
weakdeps = ["PDMats", "SparseArrays", "Statistics"]

    [deps.FillArrays.extensions]
    FillArraysPDMatsExt = "PDMats"
    FillArraysSparseArraysExt = "SparseArrays"
    FillArraysStatisticsExt = "Statistics"

[[deps.FiniteDiff]]
deps = ["ArrayInterface", "LinearAlgebra", "Requires", "Setfield", "SparseArrays"]
git-tree-sha1 = "73d1214fec245096717847c62d389a5d2ac86504"
uuid = "6a86dc24-6348-571c-b903-95158fe2bd41"
version = "2.22.0"

    [deps.FiniteDiff.extensions]
    FiniteDiffBandedMatricesExt = "BandedMatrices"
    FiniteDiffBlockBandedMatricesExt = "BlockBandedMatrices"
    FiniteDiffStaticArraysExt = "StaticArrays"

    [deps.FiniteDiff.weakdeps]
    BandedMatrices = "aae01518-5342-5314-be14-df237901396f"
    BlockBandedMatrices = "ffab5731-97b5-5995-9138-79e8c1846df0"
    StaticArrays = "90137ffa-7385-5640-81b9-e52037218182"

[[deps.FixedPointNumbers]]
deps = ["Statistics"]
git-tree-sha1 = "335bfdceacc84c5cdf16aadc768aa5ddfc5383cc"
uuid = "53c48c17-4a7d-5ca2-90c5-79b7896eea93"
version = "0.8.4"

[[deps.Fontconfig_jll]]
deps = ["Artifacts", "Bzip2_jll", "Expat_jll", "FreeType2_jll", "JLLWrappers", "Libdl", "Libuuid_jll", "Pkg", "Zlib_jll"]
git-tree-sha1 = "21efd19106a55620a188615da6d3d06cd7f6ee03"
uuid = "a3f928ae-7b40-5064-980b-68af3947d34b"
version = "2.13.93+0"

[[deps.Formatting]]
deps = ["Printf"]
git-tree-sha1 = "8339d61043228fdd3eb658d86c926cb282ae72a8"
uuid = "59287772-0a20-5a39-b81b-1366585eb4c0"
version = "0.4.2"

[[deps.ForwardDiff]]
deps = ["CommonSubexpressions", "DiffResults", "DiffRules", "LinearAlgebra", "LogExpFunctions", "NaNMath", "Preferences", "Printf", "Random", "SpecialFunctions"]
git-tree-sha1 = "cf0fe81336da9fb90944683b8c41984b08793dad"
uuid = "f6369f11-7733-5829-9624-2563aa707210"
version = "0.10.36"
weakdeps = ["StaticArrays"]

    [deps.ForwardDiff.extensions]
    ForwardDiffStaticArraysExt = "StaticArrays"

[[deps.FreeType]]
deps = ["CEnum", "FreeType2_jll"]
git-tree-sha1 = "907369da0f8e80728ab49c1c7e09327bf0d6d999"
uuid = "b38be410-82b0-50bf-ab77-7b57e271db43"
version = "4.1.1"

[[deps.FreeType2_jll]]
deps = ["Artifacts", "Bzip2_jll", "JLLWrappers", "Libdl", "Zlib_jll"]
git-tree-sha1 = "d8db6a5a2fe1381c1ea4ef2cab7c69c2de7f9ea0"
uuid = "d7e528f0-a631-5988-bf34-fe36492bcfd7"
version = "2.13.1+0"

[[deps.FreeTypeAbstraction]]
deps = ["ColorVectorSpace", "Colors", "FreeType", "GeometryBasics"]
git-tree-sha1 = "055626e1a35f6771fe99060e835b72ca61a52621"
uuid = "663a7486-cb36-511b-a19d-713bb74d65c9"
version = "0.10.1"

[[deps.FriBidi_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "aa31987c2ba8704e23c6c8ba8a4f769d5d7e4f91"
uuid = "559328eb-81f9-559d-9380-de523a88c83c"
version = "1.0.10+0"

[[deps.Future]]
deps = ["Random"]
uuid = "9fa8497b-333b-5362-9e8d-4d0656e87820"

[[deps.GLM]]
deps = ["Distributions", "LinearAlgebra", "Printf", "Reexport", "SparseArrays", "SpecialFunctions", "Statistics", "StatsAPI", "StatsBase", "StatsFuns", "StatsModels"]
git-tree-sha1 = "273bd1cd30768a2fddfa3fd63bbc746ed7249e5f"
uuid = "38e38edf-8417-5370-95a0-9cbb8c7f171a"
version = "1.9.0"

[[deps.GPUArraysCore]]
deps = ["Adapt"]
git-tree-sha1 = "ec632f177c0d990e64d955ccc1b8c04c485a0950"
uuid = "46192b85-c4d5-4398-a991-12ede77f4527"
version = "0.1.6"

[[deps.GeoInterface]]
deps = ["Extents"]
git-tree-sha1 = "d4f85701f569584f2cff7ba67a137d03f0cfb7d0"
uuid = "cf35fbd7-0cd7-5166-be24-54bfbe79505f"
version = "1.3.3"

[[deps.GeometryBasics]]
deps = ["EarCut_jll", "Extents", "GeoInterface", "IterTools", "LinearAlgebra", "StaticArrays", "StructArrays", "Tables"]
git-tree-sha1 = "5694b56ccf9d15addedc35e9a4ba9c317721b788"
uuid = "5c1252a2-5f33-56bf-86c9-59e7332b4326"
version = "0.4.10"

[[deps.Gettext_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl", "Libiconv_jll", "Pkg", "XML2_jll"]
git-tree-sha1 = "9b02998aba7bf074d14de89f9d37ca24a1a0b046"
uuid = "78b55507-aeef-58d4-861c-77aaff3498b1"
version = "0.21.0+0"

[[deps.Glib_jll]]
deps = ["Artifacts", "Gettext_jll", "JLLWrappers", "Libdl", "Libffi_jll", "Libiconv_jll", "Libmount_jll", "PCRE2_jll", "Zlib_jll"]
git-tree-sha1 = "e94c92c7bf4819685eb80186d51c43e71d4afa17"
uuid = "7746bdde-850d-59dc-9ae8-88ece973131d"
version = "2.76.5+0"

[[deps.GraphMakie]]
deps = ["DataStructures", "GeometryBasics", "Graphs", "LinearAlgebra", "Makie", "NetworkLayout", "PolynomialRoots", "SimpleTraits", "StaticArrays"]
git-tree-sha1 = "2edb7248e503c2a89230e30785cb163c3f7bedfb"
uuid = "1ecd5474-83a3-4783-bb4f-06765db800d2"
version = "0.5.9"

[[deps.Graphics]]
deps = ["Colors", "LinearAlgebra", "NaNMath"]
git-tree-sha1 = "d61890399bc535850c4bf08e4e0d3a7ad0f21cbd"
uuid = "a2bd30eb-e257-5431-a919-1863eab51364"
version = "1.1.2"

[[deps.Graphite2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "344bf40dcab1073aca04aa0df4fb092f920e4011"
uuid = "3b182d85-2403-5c21-9c21-1e1f0cc25472"
version = "1.3.14+0"

[[deps.Graphs]]
deps = ["ArnoldiMethod", "Compat", "DataStructures", "Distributed", "Inflate", "LinearAlgebra", "Random", "SharedArrays", "SimpleTraits", "SparseArrays", "Statistics"]
git-tree-sha1 = "899050ace26649433ef1af25bc17a815b3db52b7"
uuid = "86223c79-3864-5bf0-83f7-82e725a168b6"
version = "1.9.0"

[[deps.GridLayoutBase]]
deps = ["GeometryBasics", "InteractiveUtils", "Observables"]
git-tree-sha1 = "af13a277efd8a6e716d79ef635d5342ccb75be61"
uuid = "3955a311-db13-416c-9275-1d80ed98e5e9"
version = "0.10.0"

[[deps.Grisu]]
git-tree-sha1 = "53bb909d1151e57e2484c3d1b53e19552b887fb2"
uuid = "42e2da0e-8278-4e71-bc24-59509adca0fe"
version = "1.0.2"

[[deps.HarfBuzz_jll]]
deps = ["Artifacts", "Cairo_jll", "Fontconfig_jll", "FreeType2_jll", "Glib_jll", "Graphite2_jll", "JLLWrappers", "Libdl", "Libffi_jll", "Pkg"]
git-tree-sha1 = "129acf094d168394e80ee1dc4bc06ec835e510a3"
uuid = "2e76f6c2-a576-52d4-95c1-20adfe4de566"
version = "2.8.1+1"

[[deps.HypergeometricFunctions]]
deps = ["DualNumbers", "LinearAlgebra", "OpenLibm_jll", "SpecialFunctions"]
git-tree-sha1 = "f218fe3736ddf977e0e772bc9a586b2383da2685"
uuid = "34004b35-14d8-5ef3-9330-4cdb6864b03a"
version = "0.3.23"

[[deps.Hyperscript]]
deps = ["Test"]
git-tree-sha1 = "179267cfa5e712760cd43dcae385d7ea90cc25a4"
uuid = "47d2ed2b-36de-50cf-bf87-49c2cf4b8b91"
version = "0.0.5"

[[deps.HypertextLiteral]]
deps = ["Tricks"]
git-tree-sha1 = "7134810b1afce04bbc1045ca1985fbe81ce17653"
uuid = "ac1192a8-f4b3-4bfe-ba22-af5b92cd3ab2"
version = "0.9.5"

[[deps.IOCapture]]
deps = ["Logging", "Random"]
git-tree-sha1 = "8b72179abc660bfab5e28472e019392b97d0985c"
uuid = "b5f81e59-6552-4d32-b1f0-c071b021bf89"
version = "0.2.4"

[[deps.ImageAxes]]
deps = ["AxisArrays", "ImageBase", "ImageCore", "Reexport", "SimpleTraits"]
git-tree-sha1 = "2e4520d67b0cef90865b3ef727594d2a58e0e1f8"
uuid = "2803e5a7-5153-5ecf-9a86-9b4c37f5f5ac"
version = "0.6.11"

[[deps.ImageBase]]
deps = ["ImageCore", "Reexport"]
git-tree-sha1 = "eb49b82c172811fd2c86759fa0553a2221feb909"
uuid = "c817782e-172a-44cc-b673-b171935fbb9e"
version = "0.1.7"

[[deps.ImageCore]]
deps = ["ColorVectorSpace", "Colors", "FixedPointNumbers", "MappedArrays", "MosaicViews", "OffsetArrays", "PaddedViews", "PrecompileTools", "Reexport"]
git-tree-sha1 = "b2a7eaa169c13f5bcae8131a83bc30eff8f71be0"
uuid = "a09fc81d-aa75-5fe9-8630-4744c3626534"
version = "0.10.2"

[[deps.ImageIO]]
deps = ["FileIO", "IndirectArrays", "JpegTurbo", "LazyModules", "Netpbm", "OpenEXR", "PNGFiles", "QOI", "Sixel", "TiffImages", "UUIDs"]
git-tree-sha1 = "bca20b2f5d00c4fbc192c3212da8fa79f4688009"
uuid = "82e4d734-157c-48bb-816b-45c225c6df19"
version = "0.6.7"

[[deps.ImageMetadata]]
deps = ["AxisArrays", "ImageAxes", "ImageBase", "ImageCore"]
git-tree-sha1 = "355e2b974f2e3212a75dfb60519de21361ad3cb7"
uuid = "bc367c6b-8a6b-528e-b4bd-a4b897500b49"
version = "0.9.9"

[[deps.Imath_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "3d09a9f60edf77f8a4d99f9e015e8fbf9989605d"
uuid = "905a6f67-0a94-5f89-b386-d35d92009cd1"
version = "3.1.7+0"

[[deps.Indexing]]
git-tree-sha1 = "ce1566720fd6b19ff3411404d4b977acd4814f9f"
uuid = "313cdc1a-70c2-5d6a-ae34-0150d3930a38"
version = "1.1.1"

[[deps.IndirectArrays]]
git-tree-sha1 = "012e604e1c7458645cb8b436f8fba789a51b257f"
uuid = "9b13fd28-a010-5f03-acff-a1bbcff69959"
version = "1.0.0"

[[deps.Inflate]]
git-tree-sha1 = "ea8031dea4aff6bd41f1df8f2fdfb25b33626381"
uuid = "d25df0c9-e2be-5dd7-82c8-3ad0b3e990b9"
version = "0.1.4"

[[deps.InlineStrings]]
deps = ["Parsers"]
git-tree-sha1 = "9cc2baf75c6d09f9da536ddf58eb2f29dedaf461"
uuid = "842dd82b-1e85-43dc-bf29-5d0ee9dffc48"
version = "1.4.0"

[[deps.IntegerMathUtils]]
git-tree-sha1 = "b8ffb903da9f7b8cf695a8bead8e01814aa24b30"
uuid = "18e54dd8-cb9d-406c-a71d-865a43cbb235"
version = "0.1.2"

[[deps.IntelOpenMP_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "5fdf2fe6724d8caabf43b557b84ce53f3b7e2f6b"
uuid = "1d5cc7b8-4909-519e-a0f8-d0f5ad9712d0"
version = "2024.0.2+0"

[[deps.InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"

[[deps.Interpolations]]
deps = ["Adapt", "AxisAlgorithms", "ChainRulesCore", "LinearAlgebra", "OffsetArrays", "Random", "Ratios", "Requires", "SharedArrays", "SparseArrays", "StaticArrays", "WoodburyMatrices"]
git-tree-sha1 = "88a101217d7cb38a7b481ccd50d21876e1d1b0e0"
uuid = "a98d9a8b-a2ab-59e6-89dd-64a1c18fca59"
version = "0.15.1"

    [deps.Interpolations.extensions]
    InterpolationsUnitfulExt = "Unitful"

    [deps.Interpolations.weakdeps]
    Unitful = "1986cc42-f94f-5a68-af5c-568840ba703d"

[[deps.IntervalArithmetic]]
deps = ["CRlibm", "RoundingEmulator"]
git-tree-sha1 = "c274ec586ea58eb7b42afd0c5d67e50ff50229b5"
uuid = "d1acc4aa-44c8-5952-acd4-ba5d80a2a253"
version = "0.22.5"
weakdeps = ["DiffRules", "RecipesBase"]

    [deps.IntervalArithmetic.extensions]
    IntervalArithmeticDiffRulesExt = "DiffRules"
    IntervalArithmeticRecipesBaseExt = "RecipesBase"

[[deps.IntervalSets]]
git-tree-sha1 = "581191b15bcb56a2aa257e9c160085d0f128a380"
uuid = "8197267c-284f-5f27-9208-e0e47529a953"
version = "0.7.9"
weakdeps = ["Random", "Statistics"]

    [deps.IntervalSets.extensions]
    IntervalSetsRandomExt = "Random"
    IntervalSetsStatisticsExt = "Statistics"

[[deps.InvertedIndices]]
git-tree-sha1 = "0dc7b50b8d436461be01300fd8cd45aa0274b038"
uuid = "41ab1584-1d38-5bbf-9106-f11c6c58b48f"
version = "1.3.0"

[[deps.IrrationalConstants]]
git-tree-sha1 = "630b497eafcc20001bba38a4651b327dcfc491d2"
uuid = "92d709cd-6900-40b7-9082-c6be49f344b6"
version = "0.2.2"

[[deps.Isoband]]
deps = ["isoband_jll"]
git-tree-sha1 = "f9b6d97355599074dc867318950adaa6f9946137"
uuid = "f1662d9f-8043-43de-a69a-05efc1cc6ff4"
version = "0.1.1"

[[deps.IterTools]]
git-tree-sha1 = "42d5f897009e7ff2cf88db414a389e5ed1bdd023"
uuid = "c8e1da08-722c-5040-9ed9-7db0dc04731e"
version = "1.10.0"

[[deps.IteratorInterfaceExtensions]]
git-tree-sha1 = "a3f24677c21f5bbe9d2a714f95dcd58337fb2856"
uuid = "82899510-4779-5014-852e-03e436cf321d"
version = "1.0.0"

[[deps.JLLWrappers]]
deps = ["Artifacts", "Preferences"]
git-tree-sha1 = "7e5d6779a1e09a36db2a7b6cff50942a0a7d0fca"
uuid = "692b3bcd-3c85-4b1f-b108-f13ce0eb3210"
version = "1.5.0"

[[deps.JSON]]
deps = ["Dates", "Mmap", "Parsers", "Unicode"]
git-tree-sha1 = "31e996f0a15c7b280ba9f76636b3ff9e2ae58c9a"
uuid = "682c06a0-de6a-54ab-a142-c8b1cf79cde6"
version = "0.21.4"

[[deps.JpegTurbo]]
deps = ["CEnum", "FileIO", "ImageCore", "JpegTurbo_jll", "TOML"]
git-tree-sha1 = "fa6d0bcff8583bac20f1ffa708c3913ca605c611"
uuid = "b835a17e-a41a-41e7-81f0-2f016b05efe0"
version = "0.1.5"

[[deps.JpegTurbo_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "60b1194df0a3298f460063de985eae7b01bc011a"
uuid = "aacddb02-875f-59d6-b918-886e6ef4fbf8"
version = "3.0.1+0"

[[deps.KernelDensity]]
deps = ["Distributions", "DocStringExtensions", "FFTW", "Interpolations", "StatsBase"]
git-tree-sha1 = "fee018a29b60733876eb557804b5b109dd3dd8a7"
uuid = "5ab0869b-81aa-558d-bb23-cbf5423bbe9b"
version = "0.6.8"

[[deps.LAME_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "f6250b16881adf048549549fba48b1161acdac8c"
uuid = "c1c5ebd0-6772-5130-a774-d5fcae4a789d"
version = "3.100.1+0"

[[deps.LLVMOpenMP_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "d986ce2d884d49126836ea94ed5bfb0f12679713"
uuid = "1d63c593-3942-5779-bab2-d838dc0a180e"
version = "15.0.7+0"

[[deps.LZO_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "e5b909bcf985c5e2605737d2ce278ed791b89be6"
uuid = "dd4b983a-f0e5-5f8d-a1b7-129d4a5fb1ac"
version = "2.10.1+0"

[[deps.LaTeXStrings]]
git-tree-sha1 = "50901ebc375ed41dbf8058da26f9de442febbbec"
uuid = "b964fa9f-0449-5b57-a5c2-d3ea65f4040f"
version = "1.3.1"

[[deps.LazyArtifacts]]
deps = ["Artifacts", "Pkg"]
uuid = "4af54fe1-eca0-43a8-85a7-787d91b784e3"

[[deps.LazyModules]]
git-tree-sha1 = "a560dd966b386ac9ae60bdd3a3d3a326062d3c3e"
uuid = "8cdb02fc-e678-4876-92c5-9defec4f444e"
version = "0.3.1"

[[deps.LibCURL]]
deps = ["LibCURL_jll", "MozillaCACerts_jll"]
uuid = "b27032c2-a3e7-50c8-80cd-2d36dbcbfd21"
version = "0.6.4"

[[deps.LibCURL_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "MbedTLS_jll", "Zlib_jll", "nghttp2_jll"]
uuid = "deac9b47-8bc7-5906-a0fe-35ac56dc84c0"
version = "8.4.0+0"

[[deps.LibGit2]]
deps = ["Base64", "LibGit2_jll", "NetworkOptions", "Printf", "SHA"]
uuid = "76f85450-5226-5b5a-8eaa-529ad045b433"

[[deps.LibGit2_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "MbedTLS_jll"]
uuid = "e37daf67-58a4-590a-8e99-b0245dd2ffc5"
version = "1.6.4+0"

[[deps.LibSSH2_jll]]
deps = ["Artifacts", "Libdl", "MbedTLS_jll"]
uuid = "29816b5a-b9ab-546f-933c-edad1886dfa8"
version = "1.11.0+1"

[[deps.Libdl]]
uuid = "8f399da3-3557-5675-b5ff-fb832c97cbdb"

[[deps.Libffi_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "0b4a5d71f3e5200a7dff793393e09dfc2d874290"
uuid = "e9f186c6-92d2-5b65-8a66-fee21dc1b490"
version = "3.2.2+1"

[[deps.Libgcrypt_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libgpg_error_jll", "Pkg"]
git-tree-sha1 = "64613c82a59c120435c067c2b809fc61cf5166ae"
uuid = "d4300ac3-e22c-5743-9152-c294e39db1e4"
version = "1.8.7+0"

[[deps.Libgpg_error_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "c333716e46366857753e273ce6a69ee0945a6db9"
uuid = "7add5ba3-2f88-524e-9cd5-f83b8a55f7b8"
version = "1.42.0+0"

[[deps.Libiconv_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "f9557a255370125b405568f9767d6d195822a175"
uuid = "94ce4f54-9a6c-5748-9c1c-f9c7231a4531"
version = "1.17.0+0"

[[deps.Libmount_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "9c30530bf0effd46e15e0fdcf2b8636e78cbbd73"
uuid = "4b2f31a3-9ecc-558c-b454-b3730dcb73e9"
version = "2.35.0+0"

[[deps.Libuuid_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "7f3efec06033682db852f8b3bc3c1d2b0a0ab066"
uuid = "38a345b3-de98-5d2b-a5d3-14cd9215e700"
version = "2.36.0+0"

[[deps.LightXML]]
deps = ["Libdl", "XML2_jll"]
git-tree-sha1 = "3a994404d3f6709610701c7dabfc03fed87a81f8"
uuid = "9c8b4983-aa76-5018-a973-4c85ecc9e179"
version = "0.9.1"

[[deps.LineSearches]]
deps = ["LinearAlgebra", "NLSolversBase", "NaNMath", "Parameters", "Printf"]
git-tree-sha1 = "7bbea35cec17305fc70a0e5b4641477dc0789d9d"
uuid = "d3d80556-e9d4-5f37-9878-2ab0fcc64255"
version = "7.2.0"

[[deps.LinearAlgebra]]
deps = ["Libdl", "OpenBLAS_jll", "libblastrampoline_jll"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"

[[deps.LinearAlgebraX]]
deps = ["LinearAlgebra", "Mods", "Primes", "SimplePolynomials"]
git-tree-sha1 = "d76cec8007ec123c2b681269d40f94b053473fcf"
uuid = "9b3f67b0-2d00-526e-9884-9e4938f8fb88"
version = "0.2.7"

[[deps.Loess]]
deps = ["Distances", "LinearAlgebra", "Statistics", "StatsAPI"]
git-tree-sha1 = "a113a8be4c6d0c64e217b472fb6e61c760eb4022"
uuid = "4345ca2d-374a-55d4-8d30-97f9976e7612"
version = "0.6.3"

[[deps.LogExpFunctions]]
deps = ["DocStringExtensions", "IrrationalConstants", "LinearAlgebra"]
git-tree-sha1 = "7d6dd4e9212aebaeed356de34ccf262a3cd415aa"
uuid = "2ab3a3ac-af41-5b50-aa03-7779005ae688"
version = "0.3.26"

    [deps.LogExpFunctions.extensions]
    LogExpFunctionsChainRulesCoreExt = "ChainRulesCore"
    LogExpFunctionsChangesOfVariablesExt = "ChangesOfVariables"
    LogExpFunctionsInverseFunctionsExt = "InverseFunctions"

    [deps.LogExpFunctions.weakdeps]
    ChainRulesCore = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
    ChangesOfVariables = "9e997f8a-9a97-42d5-a9f1-ce6bfc15e2c0"
    InverseFunctions = "3587e190-3f89-42d0-90ee-14403ec27112"

[[deps.Logging]]
uuid = "56ddb016-857b-54e1-b83d-db4d58db5568"

[[deps.MIMEs]]
git-tree-sha1 = "65f28ad4b594aebe22157d6fac869786a255b7eb"
uuid = "6c6e2e6c-3030-632d-7369-2d6c69616d65"
version = "0.1.4"

[[deps.MKL_jll]]
deps = ["Artifacts", "IntelOpenMP_jll", "JLLWrappers", "LazyArtifacts", "Libdl"]
git-tree-sha1 = "72dc3cf284559eb8f53aa593fe62cb33f83ed0c0"
uuid = "856f044c-d86e-5d09-b602-aeab76dc8ba7"
version = "2024.0.0+0"

[[deps.MacroTools]]
deps = ["Markdown", "Random"]
git-tree-sha1 = "2fa9ee3e63fd3a4f7a9a4f4744a52f4856de82df"
uuid = "1914dd2f-81c6-5fcd-8719-6d5c9610ff09"
version = "0.5.13"

[[deps.Makie]]
deps = ["Animations", "Base64", "CRC32c", "ColorBrewer", "ColorSchemes", "ColorTypes", "Colors", "Contour", "DelaunayTriangulation", "Distributions", "DocStringExtensions", "Downloads", "FFMPEG_jll", "FileIO", "FilePaths", "FixedPointNumbers", "Formatting", "FreeType", "FreeTypeAbstraction", "GeometryBasics", "GridLayoutBase", "ImageIO", "InteractiveUtils", "IntervalArithmetic", "IntervalSets", "Isoband", "KernelDensity", "LaTeXStrings", "LinearAlgebra", "MacroTools", "MakieCore", "Markdown", "MathTeXEngine", "Observables", "OffsetArrays", "Packing", "PlotUtils", "PolygonOps", "PrecompileTools", "Printf", "REPL", "Random", "RelocatableFolders", "Scratch", "ShaderAbstractions", "Showoff", "SignedDistanceFields", "SparseArrays", "StableHashTraits", "Statistics", "StatsBase", "StatsFuns", "StructArrays", "TriplotBase", "UnicodeFun"]
git-tree-sha1 = "40c5dfbb99c91835171536cd571fe6f1ba18ff97"
uuid = "ee78f7c6-11fb-53f2-987a-cfe4a2b5a57a"
version = "0.20.7"

[[deps.MakieCore]]
deps = ["Observables", "REPL"]
git-tree-sha1 = "248b7a4be0f92b497f7a331aed02c1e9a878f46b"
uuid = "20f20a25-4f0e-4fdf-b5d1-57303727442b"
version = "0.7.3"

[[deps.MappedArrays]]
git-tree-sha1 = "2dab0221fe2b0f2cb6754eaa743cc266339f527e"
uuid = "dbb5928d-eab1-5f90-85c2-b9b0edb7c900"
version = "0.4.2"

[[deps.Markdown]]
deps = ["Base64"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"

[[deps.MathOptInterface]]
deps = ["BenchmarkTools", "CodecBzip2", "CodecZlib", "DataStructures", "ForwardDiff", "JSON", "LinearAlgebra", "MutableArithmetics", "NaNMath", "OrderedCollections", "PrecompileTools", "Printf", "SparseArrays", "SpecialFunctions", "Test", "Unicode"]
git-tree-sha1 = "8b40681684df46785a0012d352982e22ac3be59e"
uuid = "b8f27783-ece8-5eb3-8dc8-9495eed66fee"
version = "1.25.2"

[[deps.MathTeXEngine]]
deps = ["AbstractTrees", "Automa", "DataStructures", "FreeTypeAbstraction", "GeometryBasics", "LaTeXStrings", "REPL", "RelocatableFolders", "UnicodeFun"]
git-tree-sha1 = "96ca8a313eb6437db5ffe946c457a401bbb8ce1d"
uuid = "0a4f8689-d25c-4efe-a92b-7142dfc1aa53"
version = "0.5.7"

[[deps.MbedTLS_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "c8ffd9c3-330d-5841-b78e-0817d7145fa1"
version = "2.28.2+1"

[[deps.Missings]]
deps = ["DataAPI"]
git-tree-sha1 = "f66bdc5de519e8f8ae43bdc598782d35a25b1272"
uuid = "e1d29d7a-bbdc-5cf2-9ac0-f12de2c33e28"
version = "1.1.0"

[[deps.Mmap]]
uuid = "a63ad114-7e13-5084-954f-fe012c677804"

[[deps.Mods]]
git-tree-sha1 = "924f962b524a71eef7a21dae1e6853817f9b658f"
uuid = "7475f97c-0381-53b1-977b-4c60186c8d62"
version = "2.2.4"

[[deps.MosaicViews]]
deps = ["MappedArrays", "OffsetArrays", "PaddedViews", "StackViews"]
git-tree-sha1 = "7b86a5d4d70a9f5cdf2dacb3cbe6d251d1a61dbe"
uuid = "e94cdb99-869f-56ef-bcf0-1ae2bcbe0389"
version = "0.3.4"

[[deps.MozillaCACerts_jll]]
uuid = "14a3606d-f60d-562e-9121-12d972cd8159"
version = "2023.1.10"

[[deps.Multisets]]
git-tree-sha1 = "8d852646862c96e226367ad10c8af56099b4047e"
uuid = "3b2b4ff1-bcff-5658-a3ee-dbcf1ce5ac09"
version = "0.4.4"

[[deps.MutableArithmetics]]
deps = ["LinearAlgebra", "SparseArrays", "Test"]
git-tree-sha1 = "806eea990fb41f9b36f1253e5697aa645bf6a9f8"
uuid = "d8a4904e-b15c-11e9-3269-09a3773c0cb0"
version = "1.4.0"

[[deps.NLSolversBase]]
deps = ["DiffResults", "Distributed", "FiniteDiff", "ForwardDiff"]
git-tree-sha1 = "a0b464d183da839699f4c79e7606d9d186ec172c"
uuid = "d41bc354-129a-5804-8e4c-c37616107c6c"
version = "7.8.3"

[[deps.NaNMath]]
deps = ["OpenLibm_jll"]
git-tree-sha1 = "0877504529a3e5c3343c6f8b4c0381e57e4387e4"
uuid = "77ba4419-2d1f-58cd-9bb1-8ffee604a2e3"
version = "1.0.2"

[[deps.NearestNeighbors]]
deps = ["Distances", "StaticArrays"]
git-tree-sha1 = "ded64ff6d4fdd1cb68dfcbb818c69e144a5b2e4c"
uuid = "b8a86587-4115-5ab1-83bc-aa920d37bbce"
version = "0.4.16"

[[deps.Netpbm]]
deps = ["FileIO", "ImageCore", "ImageMetadata"]
git-tree-sha1 = "d92b107dbb887293622df7697a2223f9f8176fcd"
uuid = "f09324ee-3d7c-5217-9330-fc30815ba969"
version = "1.1.1"

[[deps.NetworkLayout]]
deps = ["GeometryBasics", "LinearAlgebra", "Random", "Requires", "StaticArrays"]
git-tree-sha1 = "91bb2fedff8e43793650e7a677ccda6e6e6e166b"
uuid = "46757867-2c16-5918-afeb-47bfcb05e46a"
version = "0.4.6"
weakdeps = ["Graphs"]

    [deps.NetworkLayout.extensions]
    NetworkLayoutGraphsExt = "Graphs"

[[deps.NetworkOptions]]
uuid = "ca575930-c2e3-43a9-ace4-1e988b2c1908"
version = "1.2.0"

[[deps.Observables]]
git-tree-sha1 = "7438a59546cf62428fc9d1bc94729146d37a7225"
uuid = "510215fc-4207-5dde-b226-833fc4488ee2"
version = "0.5.5"

[[deps.OffsetArrays]]
git-tree-sha1 = "6a731f2b5c03157418a20c12195eb4b74c8f8621"
uuid = "6fe1bfb0-de20-5000-8ca7-80f57d26f881"
version = "1.13.0"
weakdeps = ["Adapt"]

    [deps.OffsetArrays.extensions]
    OffsetArraysAdaptExt = "Adapt"

[[deps.Ogg_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "887579a3eb005446d514ab7aeac5d1d027658b8f"
uuid = "e7412a2a-1a6e-54c0-be00-318e2571c051"
version = "1.3.5+1"

[[deps.OpenBLAS_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Libdl"]
uuid = "4536629a-c528-5b80-bd46-f80d51c5b363"
version = "0.3.23+2"

[[deps.OpenEXR]]
deps = ["Colors", "FileIO", "OpenEXR_jll"]
git-tree-sha1 = "327f53360fdb54df7ecd01e96ef1983536d1e633"
uuid = "52e1d378-f018-4a11-a4be-720524705ac7"
version = "0.3.2"

[[deps.OpenEXR_jll]]
deps = ["Artifacts", "Imath_jll", "JLLWrappers", "Libdl", "Zlib_jll"]
git-tree-sha1 = "a4ca623df1ae99d09bc9868b008262d0c0ac1e4f"
uuid = "18a262bb-aa17-5467-a713-aee519bc75cb"
version = "3.1.4+0"

[[deps.OpenLibm_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "05823500-19ac-5b8b-9628-191a04bc5112"
version = "0.8.1+2"

[[deps.OpenSSL_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "60e3045590bd104a16fefb12836c00c0ef8c7f8c"
uuid = "458c3c95-2e84-50aa-8efc-19380b2a3a95"
version = "3.0.13+0"

[[deps.OpenSpecFun_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "13652491f6856acfd2db29360e1bbcd4565d04f1"
uuid = "efe28fd5-8261-553b-a9e1-b2916fc3738e"
version = "0.5.5+0"

[[deps.Optim]]
deps = ["Compat", "FillArrays", "ForwardDiff", "LineSearches", "LinearAlgebra", "MathOptInterface", "NLSolversBase", "NaNMath", "Parameters", "PositiveFactorizations", "Printf", "SparseArrays", "StatsBase"]
git-tree-sha1 = "d024bfb56144d947d4fafcd9cb5cafbe3410b133"
uuid = "429524aa-4258-5aef-a3af-852621145aeb"
version = "1.9.2"

[[deps.Opus_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "51a08fb14ec28da2ec7a927c4337e4332c2a4720"
uuid = "91d4177d-7536-5919-b921-800302f37372"
version = "1.3.2+0"

[[deps.OrderedCollections]]
git-tree-sha1 = "dfdf5519f235516220579f949664f1bf44e741c5"
uuid = "bac558e1-5e72-5ebc-8fee-abe8a469f55d"
version = "1.6.3"

[[deps.PCRE2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "efcefdf7-47ab-520b-bdef-62a2eaa19f15"
version = "10.42.0+1"

[[deps.PDMats]]
deps = ["LinearAlgebra", "SparseArrays", "SuiteSparse"]
git-tree-sha1 = "949347156c25054de2db3b166c52ac4728cbad65"
uuid = "90014a1f-27ba-587c-ab20-58faa44d9150"
version = "0.11.31"

[[deps.PNGFiles]]
deps = ["Base64", "CEnum", "ImageCore", "IndirectArrays", "OffsetArrays", "libpng_jll"]
git-tree-sha1 = "67186a2bc9a90f9f85ff3cc8277868961fb57cbd"
uuid = "f57f5aa1-a3ce-4bc8-8ab9-96f992907883"
version = "0.4.3"

[[deps.Packing]]
deps = ["GeometryBasics"]
git-tree-sha1 = "ec3edfe723df33528e085e632414499f26650501"
uuid = "19eb6ba3-879d-56ad-ad62-d5c202156566"
version = "0.5.0"

[[deps.PaddedViews]]
deps = ["OffsetArrays"]
git-tree-sha1 = "0fac6313486baae819364c52b4f483450a9d793f"
uuid = "5432bcbf-9aad-5242-b902-cca2824c8663"
version = "0.5.12"

[[deps.Pango_jll]]
deps = ["Artifacts", "Cairo_jll", "Fontconfig_jll", "FreeType2_jll", "FriBidi_jll", "Glib_jll", "HarfBuzz_jll", "JLLWrappers", "Libdl"]
git-tree-sha1 = "4745216e94f71cb768d58330b059c9b76f32cb66"
uuid = "36c8627f-9965-5494-a995-c6b170f724f3"
version = "1.50.14+0"

[[deps.Parameters]]
deps = ["OrderedCollections", "UnPack"]
git-tree-sha1 = "34c0e9ad262e5f7fc75b10a9952ca7692cfc5fbe"
uuid = "d96e819e-fc66-5662-9728-84c9c7592b0a"
version = "0.12.3"

[[deps.Parsers]]
deps = ["Dates", "PrecompileTools", "UUIDs"]
git-tree-sha1 = "8489905bcdbcfac64d1daa51ca07c0d8f0283821"
uuid = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"
version = "2.8.1"

[[deps.Permutations]]
deps = ["Combinatorics", "LinearAlgebra", "Random"]
git-tree-sha1 = "eb3f9df2457819bf0a9019bd93cc451697a0751e"
uuid = "2ae35dd2-176d-5d53-8349-f30d82d94d4f"
version = "0.4.20"

[[deps.PikaParser]]
deps = ["DocStringExtensions"]
git-tree-sha1 = "d6ff87de27ff3082131f31a714d25ab6d0a88abf"
uuid = "3bbf5609-3e7b-44cd-8549-7c69f321e792"
version = "0.6.1"

[[deps.Pixman_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "LLVMOpenMP_jll", "Libdl"]
git-tree-sha1 = "64779bc4c9784fee475689a1752ef4d5747c5e87"
uuid = "30392449-352a-5448-841d-b1acce4e97dc"
version = "0.42.2+0"

[[deps.Pkg]]
deps = ["Artifacts", "Dates", "Downloads", "FileWatching", "LibGit2", "Libdl", "Logging", "Markdown", "Printf", "REPL", "Random", "SHA", "Serialization", "TOML", "Tar", "UUIDs", "p7zip_jll"]
uuid = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"
version = "1.10.0"

[[deps.PkgVersion]]
deps = ["Pkg"]
git-tree-sha1 = "f9501cc0430a26bc3d156ae1b5b0c1b47af4d6da"
uuid = "eebad327-c553-4316-9ea0-9fa01ccd7688"
version = "0.3.3"

[[deps.PlotUtils]]
deps = ["ColorSchemes", "Colors", "Dates", "PrecompileTools", "Printf", "Random", "Reexport", "Statistics"]
git-tree-sha1 = "862942baf5663da528f66d24996eb6da85218e76"
uuid = "995b91a9-d308-5afd-9ec6-746e21dbc043"
version = "1.4.0"

[[deps.PlutoTest]]
deps = ["HypertextLiteral", "InteractiveUtils", "Markdown", "Test"]
git-tree-sha1 = "17aa9b81106e661cffa1c4c36c17ee1c50a86eda"
uuid = "cb4044da-4d16-4ffa-a6a3-8cad7f73ebdc"
version = "0.2.2"

[[deps.PlutoUI]]
deps = ["AbstractPlutoDingetjes", "Base64", "ColorTypes", "Dates", "FixedPointNumbers", "Hyperscript", "HypertextLiteral", "IOCapture", "InteractiveUtils", "JSON", "Logging", "MIMEs", "Markdown", "Random", "Reexport", "URIs", "UUIDs"]
git-tree-sha1 = "68723afdb616445c6caaef6255067a8339f91325"
uuid = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
version = "0.7.55"

[[deps.PolygonOps]]
git-tree-sha1 = "77b3d3605fc1cd0b42d95eba87dfcd2bf67d5ff6"
uuid = "647866c9-e3ac-4575-94e7-e3d426903924"
version = "0.1.2"

[[deps.PolynomialRoots]]
git-tree-sha1 = "5f807b5345093487f733e520a1b7395ee9324825"
uuid = "3a141323-8675-5d76-9d11-e1df1406c778"
version = "1.0.0"

[[deps.Polynomials]]
deps = ["LinearAlgebra", "RecipesBase", "Setfield", "SparseArrays"]
git-tree-sha1 = "a9c7a523d5ed375be3983db190f6a5874ae9286d"
uuid = "f27b6e38-b328-58d1-80ce-0feddd5e7a45"
version = "4.0.6"
weakdeps = ["ChainRulesCore", "FFTW", "MakieCore", "MutableArithmetics"]

    [deps.Polynomials.extensions]
    PolynomialsChainRulesCoreExt = "ChainRulesCore"
    PolynomialsFFTWExt = "FFTW"
    PolynomialsMakieCoreExt = "MakieCore"
    PolynomialsMutableArithmeticsExt = "MutableArithmetics"

[[deps.PooledArrays]]
deps = ["DataAPI", "Future"]
git-tree-sha1 = "36d8b4b899628fb92c2749eb488d884a926614d3"
uuid = "2dfb63ee-cc39-5dd5-95bd-886bf059d720"
version = "1.4.3"

[[deps.PositiveFactorizations]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "17275485f373e6673f7e7f97051f703ed5b15b20"
uuid = "85a6dd25-e78a-55b7-8502-1745935b8125"
version = "0.2.4"

[[deps.PrecompileTools]]
deps = ["Preferences"]
git-tree-sha1 = "03b4c25b43cb84cee5c90aa9b5ea0a78fd848d2f"
uuid = "aea7be01-6a6a-4083-8856-8a6e6704d82a"
version = "1.2.0"

[[deps.Preferences]]
deps = ["TOML"]
git-tree-sha1 = "00805cd429dcb4870060ff49ef443486c262e38e"
uuid = "21216c6a-2e73-6563-6e65-726566657250"
version = "1.4.1"

[[deps.PrettyTables]]
deps = ["Crayons", "LaTeXStrings", "Markdown", "PrecompileTools", "Printf", "Reexport", "StringManipulation", "Tables"]
git-tree-sha1 = "88b895d13d53b5577fd53379d913b9ab9ac82660"
uuid = "08abe8d2-0d0c-5749-adfa-8a2ac140af0d"
version = "2.3.1"

[[deps.Primes]]
deps = ["IntegerMathUtils"]
git-tree-sha1 = "1d05623b5952aed1307bf8b43bec8b8d1ef94b6e"
uuid = "27ebfcd6-29c5-5fa9-bf4b-fb8fc14df3ae"
version = "0.5.5"

[[deps.Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"

[[deps.Profile]]
deps = ["Printf"]
uuid = "9abbd945-dff8-562f-b5e8-e1ebf5ef1b79"

[[deps.ProgressMeter]]
deps = ["Distributed", "Printf"]
git-tree-sha1 = "00099623ffee15972c16111bcf84c58a0051257c"
uuid = "92933f4c-e287-5a05-a399-4b506db050ca"
version = "1.9.0"

[[deps.QOI]]
deps = ["ColorTypes", "FileIO", "FixedPointNumbers"]
git-tree-sha1 = "18e8f4d1426e965c7b532ddd260599e1510d26ce"
uuid = "4b34888f-f399-49d4-9bb3-47ed5cae4e65"
version = "1.0.0"

[[deps.QuadGK]]
deps = ["DataStructures", "LinearAlgebra"]
git-tree-sha1 = "9b23c31e76e333e6fb4c1595ae6afa74966a729e"
uuid = "1fd47b50-473d-5c70-9696-f719f8f3bcdc"
version = "2.9.4"

[[deps.REPL]]
deps = ["InteractiveUtils", "Markdown", "Sockets", "Unicode"]
uuid = "3fa0cd96-eef1-5676-8a61-b3b8758bbffb"

[[deps.Random]]
deps = ["SHA"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"

[[deps.RangeArrays]]
git-tree-sha1 = "b9039e93773ddcfc828f12aadf7115b4b4d225f5"
uuid = "b3c3ace0-ae52-54e7-9d0b-2c1406fd6b9d"
version = "0.3.2"

[[deps.Ratios]]
deps = ["Requires"]
git-tree-sha1 = "1342a47bf3260ee108163042310d26f2be5ec90b"
uuid = "c84ed2f1-dad5-54f0-aa8e-dbefe2724439"
version = "0.4.5"
weakdeps = ["FixedPointNumbers"]

    [deps.Ratios.extensions]
    RatiosFixedPointNumbersExt = "FixedPointNumbers"

[[deps.RecipesBase]]
deps = ["PrecompileTools"]
git-tree-sha1 = "5c3d09cc4f31f5fc6af001c250bf1278733100ff"
uuid = "3cdcf5f2-1ef4-517c-9805-6587b60abb01"
version = "1.3.4"

[[deps.Reexport]]
git-tree-sha1 = "45e428421666073eab6f2da5c9d310d99bb12f9b"
uuid = "189a3867-3050-52da-a836-e630ba90ab69"
version = "1.2.2"

[[deps.RelocatableFolders]]
deps = ["SHA", "Scratch"]
git-tree-sha1 = "ffdaf70d81cf6ff22c2b6e733c900c3321cab864"
uuid = "05181044-ff0b-4ac5-8273-598c1e38db00"
version = "1.0.1"

[[deps.Requires]]
deps = ["UUIDs"]
git-tree-sha1 = "838a3a4188e2ded87a4f9f184b4b0d78a1e91cb7"
uuid = "ae029012-a4dd-5104-9daa-d747884805df"
version = "1.3.0"

[[deps.RingLists]]
deps = ["Random"]
git-tree-sha1 = "f39da63aa6d2d88e0c1bd20ed6a3ff9ea7171ada"
uuid = "286e9d63-9694-5540-9e3c-4e6708fa07b2"
version = "0.2.8"

[[deps.Rmath]]
deps = ["Random", "Rmath_jll"]
git-tree-sha1 = "f65dcb5fa46aee0cf9ed6274ccbd597adc49aa7b"
uuid = "79098fc4-a85e-5d69-aa6a-4863f24498fa"
version = "0.7.1"

[[deps.Rmath_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "6ed52fdd3382cf21947b15e8870ac0ddbff736da"
uuid = "f50d1b31-88e8-58de-be2c-1cc44531875f"
version = "0.4.0+0"

[[deps.RoundingEmulator]]
git-tree-sha1 = "40b9edad2e5287e05bd413a38f61a8ff55b9557b"
uuid = "5eaf0fd0-dfba-4ccb-bf02-d820a40db705"
version = "0.2.1"

[[deps.SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"
version = "0.7.0"

[[deps.Scratch]]
deps = ["Dates"]
git-tree-sha1 = "3bac05bc7e74a75fd9cba4295cde4045d9fe2386"
uuid = "6c6a2e73-6563-6170-7368-637461726353"
version = "1.2.1"

[[deps.SentinelArrays]]
deps = ["Dates", "Random"]
git-tree-sha1 = "0e7508ff27ba32f26cd459474ca2ede1bc10991f"
uuid = "91c51154-3ec4-41a3-a24f-3f23e20d615c"
version = "1.4.1"

[[deps.Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"

[[deps.Setfield]]
deps = ["ConstructionBase", "Future", "MacroTools", "StaticArraysCore"]
git-tree-sha1 = "e2cc6d8c88613c05e1defb55170bf5ff211fbeac"
uuid = "efcf1570-3423-57d1-acb7-fd33fddbac46"
version = "1.1.1"

[[deps.ShaderAbstractions]]
deps = ["ColorTypes", "FixedPointNumbers", "GeometryBasics", "LinearAlgebra", "Observables", "StaticArrays", "StructArrays", "Tables"]
git-tree-sha1 = "79123bc60c5507f035e6d1d9e563bb2971954ec8"
uuid = "65257c39-d410-5151-9873-9b3e5be5013e"
version = "0.4.1"

[[deps.SharedArrays]]
deps = ["Distributed", "Mmap", "Random", "Serialization"]
uuid = "1a1011a3-84de-559e-8e89-a11a2f7dc383"

[[deps.ShiftedArrays]]
git-tree-sha1 = "503688b59397b3307443af35cd953a13e8005c16"
uuid = "1277b4bf-5013-50f5-be3d-901d8477a67a"
version = "2.0.0"

[[deps.Showoff]]
deps = ["Dates", "Grisu"]
git-tree-sha1 = "91eddf657aca81df9ae6ceb20b959ae5653ad1de"
uuid = "992d4aef-0814-514b-bc4d-f2e9a6c4116f"
version = "1.0.3"

[[deps.SignedDistanceFields]]
deps = ["Random", "Statistics", "Test"]
git-tree-sha1 = "d263a08ec505853a5ff1c1ebde2070419e3f28e9"
uuid = "73760f76-fbc4-59ce-8f25-708e95d2df96"
version = "0.4.0"

[[deps.SimpleGraphs]]
deps = ["AbstractLattices", "Combinatorics", "DataStructures", "IterTools", "LightXML", "LinearAlgebra", "LinearAlgebraX", "Optim", "Primes", "Random", "RingLists", "SimplePartitions", "SimplePolynomials", "SimpleRandom", "SparseArrays", "Statistics"]
git-tree-sha1 = "f65caa24a622f985cc341de81d3f9744435d0d0f"
uuid = "55797a34-41de-5266-9ec1-32ac4eb504d3"
version = "0.8.6"

[[deps.SimplePartitions]]
deps = ["AbstractLattices", "DataStructures", "Permutations"]
git-tree-sha1 = "e9330391d04241eafdc358713b48396619c83bcb"
uuid = "ec83eff0-a5b5-5643-ae32-5cbf6eedec9d"
version = "0.3.1"

[[deps.SimplePolynomials]]
deps = ["Mods", "Multisets", "Polynomials", "Primes"]
git-tree-sha1 = "7063828369cafa93f3187b3d0159f05582011405"
uuid = "cc47b68c-3164-5771-a705-2bc0097375a0"
version = "0.2.17"

[[deps.SimpleRandom]]
deps = ["Distributions", "LinearAlgebra", "Random"]
git-tree-sha1 = "3a6fb395e37afab81aeea85bae48a4db5cd7244a"
uuid = "a6525b86-64cd-54fa-8f65-62fc48bdc0e8"
version = "0.3.1"

[[deps.SimpleTraits]]
deps = ["InteractiveUtils", "MacroTools"]
git-tree-sha1 = "5d7e3f4e11935503d3ecaf7186eac40602e7d231"
uuid = "699a6c99-e7fa-54fc-8d76-47d257e15c1d"
version = "0.9.4"

[[deps.Sixel]]
deps = ["Dates", "FileIO", "ImageCore", "IndirectArrays", "OffsetArrays", "REPL", "libsixel_jll"]
git-tree-sha1 = "2da10356e31327c7096832eb9cd86307a50b1eb6"
uuid = "45858cf5-a6b0-47a3-bbea-62219f50df47"
version = "0.1.3"

[[deps.Sockets]]
uuid = "6462fe0b-24de-5631-8697-dd941f90decc"

[[deps.SortingAlgorithms]]
deps = ["DataStructures"]
git-tree-sha1 = "66e0a8e672a0bdfca2c3f5937efb8538b9ddc085"
uuid = "a2af1166-a08f-5f64-846c-94a0d3cef48c"
version = "1.2.1"

[[deps.SparseArrays]]
deps = ["Libdl", "LinearAlgebra", "Random", "Serialization", "SuiteSparse_jll"]
uuid = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"
version = "1.10.0"

[[deps.SpecialFunctions]]
deps = ["IrrationalConstants", "LogExpFunctions", "OpenLibm_jll", "OpenSpecFun_jll"]
git-tree-sha1 = "e2cfc4012a19088254b3950b85c3c1d8882d864d"
uuid = "276daf66-3868-5448-9aa4-cd146d93841b"
version = "2.3.1"
weakdeps = ["ChainRulesCore"]

    [deps.SpecialFunctions.extensions]
    SpecialFunctionsChainRulesCoreExt = "ChainRulesCore"

[[deps.StableHashTraits]]
deps = ["Compat", "PikaParser", "SHA", "Tables", "TupleTools"]
git-tree-sha1 = "662f56ffe22b3985f3be7474f0aecbaf214ecf0f"
uuid = "c5dd0088-6c3f-4803-b00e-f31a60c170fa"
version = "1.1.6"

[[deps.StackViews]]
deps = ["OffsetArrays"]
git-tree-sha1 = "46e589465204cd0c08b4bd97385e4fa79a0c770c"
uuid = "cae243ae-269e-4f55-b966-ac2d0dc13c15"
version = "0.1.1"

[[deps.StaticArrays]]
deps = ["LinearAlgebra", "PrecompileTools", "Random", "StaticArraysCore"]
git-tree-sha1 = "7b0e9c14c624e435076d19aea1e5cbdec2b9ca37"
uuid = "90137ffa-7385-5640-81b9-e52037218182"
version = "1.9.2"
weakdeps = ["ChainRulesCore", "Statistics"]

    [deps.StaticArrays.extensions]
    StaticArraysChainRulesCoreExt = "ChainRulesCore"
    StaticArraysStatisticsExt = "Statistics"

[[deps.StaticArraysCore]]
git-tree-sha1 = "36b3d696ce6366023a0ea192b4cd442268995a0d"
uuid = "1e83bf80-4336-4d27-bf5d-d5a4f845583c"
version = "1.4.2"

[[deps.Statistics]]
deps = ["LinearAlgebra", "SparseArrays"]
uuid = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"
version = "1.10.0"

[[deps.StatsAPI]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "1ff449ad350c9c4cbc756624d6f8a8c3ef56d3ed"
uuid = "82ae8749-77ed-4fe6-ae5f-f523153014b0"
version = "1.7.0"

[[deps.StatsBase]]
deps = ["DataAPI", "DataStructures", "LinearAlgebra", "LogExpFunctions", "Missings", "Printf", "Random", "SortingAlgorithms", "SparseArrays", "Statistics", "StatsAPI"]
git-tree-sha1 = "1d77abd07f617c4868c33d4f5b9e1dbb2643c9cf"
uuid = "2913bbd2-ae8a-5f71-8c99-4fb6c76f3a91"
version = "0.34.2"

[[deps.StatsFuns]]
deps = ["HypergeometricFunctions", "IrrationalConstants", "LogExpFunctions", "Reexport", "Rmath", "SpecialFunctions"]
git-tree-sha1 = "f625d686d5a88bcd2b15cd81f18f98186fdc0c9a"
uuid = "4c63d2b9-4356-54db-8cca-17b64c39e42c"
version = "1.3.0"

    [deps.StatsFuns.extensions]
    StatsFunsChainRulesCoreExt = "ChainRulesCore"
    StatsFunsInverseFunctionsExt = "InverseFunctions"

    [deps.StatsFuns.weakdeps]
    ChainRulesCore = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
    InverseFunctions = "3587e190-3f89-42d0-90ee-14403ec27112"

[[deps.StatsModels]]
deps = ["DataAPI", "DataStructures", "LinearAlgebra", "Printf", "REPL", "ShiftedArrays", "SparseArrays", "StatsAPI", "StatsBase", "StatsFuns", "Tables"]
git-tree-sha1 = "5cf6c4583533ee38639f73b880f35fc85f2941e0"
uuid = "3eaba693-59b7-5ba5-a881-562e759f1c8d"
version = "0.7.3"

[[deps.StringManipulation]]
deps = ["PrecompileTools"]
git-tree-sha1 = "a04cabe79c5f01f4d723cc6704070ada0b9d46d5"
uuid = "892a3eda-7b42-436c-8928-eab12a02cf0e"
version = "0.3.4"

[[deps.StructArrays]]
deps = ["Adapt", "ConstructionBase", "DataAPI", "GPUArraysCore", "StaticArraysCore", "Tables"]
git-tree-sha1 = "1b0b1205a56dc288b71b1961d48e351520702e24"
uuid = "09ab397b-f2b6-538f-b94a-2f83cf4a842a"
version = "0.6.17"

[[deps.SuiteSparse]]
deps = ["Libdl", "LinearAlgebra", "Serialization", "SparseArrays"]
uuid = "4607b0f0-06f3-5cda-b6b1-a6196a1729e9"

[[deps.SuiteSparse_jll]]
deps = ["Artifacts", "Libdl", "libblastrampoline_jll"]
uuid = "bea87d4a-7f5b-5778-9afe-8cc45184846c"
version = "7.2.1+1"

[[deps.TOML]]
deps = ["Dates"]
uuid = "fa267f1f-6049-4f14-aa54-33bafae1ed76"
version = "1.0.3"

[[deps.TableTraits]]
deps = ["IteratorInterfaceExtensions"]
git-tree-sha1 = "c06b2f539df1c6efa794486abfb6ed2022561a39"
uuid = "3783bdb8-4a98-5b6b-af9a-565f29a5fe9c"
version = "1.0.1"

[[deps.Tables]]
deps = ["DataAPI", "DataValueInterfaces", "IteratorInterfaceExtensions", "LinearAlgebra", "OrderedCollections", "TableTraits"]
git-tree-sha1 = "cb76cf677714c095e535e3501ac7954732aeea2d"
uuid = "bd369af6-aec1-5ad0-b16a-f7cc5008161c"
version = "1.11.1"

[[deps.Tar]]
deps = ["ArgTools", "SHA"]
uuid = "a4e569a6-e804-4fa4-b0f3-eef7a1d5b13e"
version = "1.10.0"

[[deps.TensorCore]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "1feb45f88d133a655e001435632f019a9a1bcdb6"
uuid = "62fd8b95-f654-4bbd-a8a5-9c27f68ccd50"
version = "0.1.1"

[[deps.Test]]
deps = ["InteractiveUtils", "Logging", "Random", "Serialization"]
uuid = "8dfed614-e22c-5e08-85e1-65c5234f0b40"

[[deps.TiffImages]]
deps = ["ColorTypes", "DataStructures", "DocStringExtensions", "FileIO", "FixedPointNumbers", "IndirectArrays", "Inflate", "Mmap", "OffsetArrays", "PkgVersion", "ProgressMeter", "UUIDs"]
git-tree-sha1 = "34cc045dd0aaa59b8bbe86c644679bc57f1d5bd0"
uuid = "731e570b-9d59-4bfa-96dc-6df516fadf69"
version = "0.6.8"

[[deps.TranscodingStreams]]
git-tree-sha1 = "54194d92959d8ebaa8e26227dbe3cdefcdcd594f"
uuid = "3bb67fe8-82b1-5028-8e26-92a6c54297fa"
version = "0.10.3"
weakdeps = ["Random", "Test"]

    [deps.TranscodingStreams.extensions]
    TestExt = ["Test", "Random"]

[[deps.Tricks]]
git-tree-sha1 = "eae1bb484cd63b36999ee58be2de6c178105112f"
uuid = "410a4b4d-49e4-4fbc-ab6d-cb71b17b3775"
version = "0.1.8"

[[deps.TriplotBase]]
git-tree-sha1 = "4d4ed7f294cda19382ff7de4c137d24d16adc89b"
uuid = "981d1d27-644d-49a2-9326-4793e63143c3"
version = "0.1.0"

[[deps.TupleTools]]
git-tree-sha1 = "155515ed4c4236db30049ac1495e2969cc06be9d"
uuid = "9d95972d-f1c8-5527-a6e0-b4b365fa01f6"
version = "1.4.3"

[[deps.URIs]]
git-tree-sha1 = "67db6cc7b3821e19ebe75791a9dd19c9b1188f2b"
uuid = "5c2747f8-b7ea-4ff2-ba2e-563bfd36b1d4"
version = "1.5.1"

[[deps.UUIDs]]
deps = ["Random", "SHA"]
uuid = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"

[[deps.UnPack]]
git-tree-sha1 = "387c1f73762231e86e0c9c5443ce3b4a0a9a0c2b"
uuid = "3a884ed6-31ef-47d7-9d2a-63182c4928ed"
version = "1.0.2"

[[deps.Unicode]]
uuid = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"

[[deps.UnicodeFun]]
deps = ["REPL"]
git-tree-sha1 = "53915e50200959667e78a92a418594b428dffddf"
uuid = "1cfade01-22cf-5700-b092-accc4b62d6e1"
version = "0.4.1"

[[deps.WeakRefStrings]]
deps = ["DataAPI", "InlineStrings", "Parsers"]
git-tree-sha1 = "b1be2855ed9ed8eac54e5caff2afcdb442d52c23"
uuid = "ea10d353-3f73-51f8-a26c-33c1cb351aa5"
version = "1.4.2"

[[deps.WoodburyMatrices]]
deps = ["LinearAlgebra", "SparseArrays"]
git-tree-sha1 = "c1a7aa6219628fcd757dede0ca95e245c5cd9511"
uuid = "efce3f68-66dc-5838-9240-27a6d6f5f9b6"
version = "1.0.0"

[[deps.WorkerUtilities]]
git-tree-sha1 = "cd1659ba0d57b71a464a29e64dbc67cfe83d54e7"
uuid = "76eceee3-57b5-4d4a-8e66-0e911cebbf60"
version = "1.6.1"

[[deps.XML2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libiconv_jll", "Zlib_jll"]
git-tree-sha1 = "801cbe47eae69adc50f36c3caec4758d2650741b"
uuid = "02c8fc9c-b97f-50b9-bbe4-9be30ff0a78a"
version = "2.12.2+0"

[[deps.XSLT_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libgcrypt_jll", "Libgpg_error_jll", "Libiconv_jll", "Pkg", "XML2_jll", "Zlib_jll"]
git-tree-sha1 = "91844873c4085240b95e795f692c4cec4d805f8a"
uuid = "aed1982a-8fda-507f-9586-7b0439959a61"
version = "1.1.34+0"

[[deps.Xorg_libX11_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libxcb_jll", "Xorg_xtrans_jll"]
git-tree-sha1 = "afead5aba5aa507ad5a3bf01f58f82c8d1403495"
uuid = "4f6342f7-b3d2-589e-9d20-edeb45f2b2bc"
version = "1.8.6+0"

[[deps.Xorg_libXau_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "6035850dcc70518ca32f012e46015b9beeda49d8"
uuid = "0c0b7dd1-d40b-584c-a123-a41640f87eec"
version = "1.0.11+0"

[[deps.Xorg_libXdmcp_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "34d526d318358a859d7de23da945578e8e8727b7"
uuid = "a3789734-cfe1-5b06-b2d0-1dd0d9d62d05"
version = "1.1.4+0"

[[deps.Xorg_libXext_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll"]
git-tree-sha1 = "b7c0aa8c376b31e4852b360222848637f481f8c3"
uuid = "1082639a-0dae-5f34-9b06-72781eeb8cb3"
version = "1.3.4+4"

[[deps.Xorg_libXrender_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll"]
git-tree-sha1 = "19560f30fd49f4d4efbe7002a1037f8c43d43b96"
uuid = "ea2f1a96-1ddc-540d-b46f-429655e07cfa"
version = "0.9.10+4"

[[deps.Xorg_libpthread_stubs_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "8fdda4c692503d44d04a0603d9ac0982054635f9"
uuid = "14d82f49-176c-5ed1-bb49-ad3f5cbd8c74"
version = "0.1.1+0"

[[deps.Xorg_libxcb_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "XSLT_jll", "Xorg_libXau_jll", "Xorg_libXdmcp_jll", "Xorg_libpthread_stubs_jll"]
git-tree-sha1 = "b4bfde5d5b652e22b9c790ad00af08b6d042b97d"
uuid = "c7cfdc94-dc32-55de-ac96-5a1b8d977c5b"
version = "1.15.0+0"

[[deps.Xorg_xtrans_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "e92a1a012a10506618f10b7047e478403a046c77"
uuid = "c5fb5394-a638-5e4d-96e5-b29de1b5cf10"
version = "1.5.0+0"

[[deps.Zlib_jll]]
deps = ["Libdl"]
uuid = "83775a58-1f1d-513f-b197-d71354ab007a"
version = "1.2.13+1"

[[deps.isoband_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "51b5eeb3f98367157a7a12a1fb0aa5328946c03c"
uuid = "9a68df92-36a6-505f-a73e-abb412b6bfb4"
version = "0.2.3+0"

[[deps.libaom_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "3a2ea60308f0996d26f1e5354e10c24e9ef905d4"
uuid = "a4ae2306-e953-59d6-aa16-d00cac43593b"
version = "3.4.0+0"

[[deps.libass_jll]]
deps = ["Artifacts", "Bzip2_jll", "FreeType2_jll", "FriBidi_jll", "HarfBuzz_jll", "JLLWrappers", "Libdl", "Pkg", "Zlib_jll"]
git-tree-sha1 = "5982a94fcba20f02f42ace44b9894ee2b140fe47"
uuid = "0ac62f75-1d6f-5e53-bd7c-93b484bb37c0"
version = "0.15.1+0"

[[deps.libblastrampoline_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850b90-86db-534c-a0d3-1478176c7d93"
version = "5.8.0+1"

[[deps.libfdk_aac_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "daacc84a041563f965be61859a36e17c4e4fcd55"
uuid = "f638f0a6-7fb0-5443-88ba-1cc74229b280"
version = "2.0.2+0"

[[deps.libpng_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Zlib_jll"]
git-tree-sha1 = "93284c28274d9e75218a416c65ec49d0e0fcdf3d"
uuid = "b53b4c65-9356-5827-b1ea-8c7a1a84506f"
version = "1.6.40+0"

[[deps.libsixel_jll]]
deps = ["Artifacts", "JLLWrappers", "JpegTurbo_jll", "Libdl", "Pkg", "libpng_jll"]
git-tree-sha1 = "d4f63314c8aa1e48cd22aa0c17ed76cd1ae48c3c"
uuid = "075b6546-f08a-558a-be8f-8157d0f608a5"
version = "1.10.3+0"

[[deps.libvorbis_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Ogg_jll", "Pkg"]
git-tree-sha1 = "b910cb81ef3fe6e78bf6acee440bda86fd6ae00c"
uuid = "f27f6e37-5d2b-51aa-960f-b287f2bc3b7a"
version = "1.3.7+1"

[[deps.nghttp2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850ede-7688-5339-a07c-302acd2aaf8d"
version = "1.52.0+1"

[[deps.p7zip_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "3f19e933-33d8-53b3-aaab-bd5110c3b7a0"
version = "17.4.0+2"

[[deps.x264_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "4fea590b89e6ec504593146bf8b988b2c00922b2"
uuid = "1270edf5-f2f9-52d2-97e9-ab00b5d0237a"
version = "2021.5.5+0"

[[deps.x265_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "ee567a171cce03570d77ad3a43e90218e38937a9"
uuid = "dfaa095f-4041-5dcd-9319-2fabd8486b76"
version = "3.5.0+0"
"""

# ╔═╡ Cell order:
# ╟─fd20d87b-204d-4f0c-b830-bfbe1b396fcb
# ╟─0e30624c-65fc-11eb-185d-1d018f68f82c
# ╟─f4266196-64aa-11eb-3fc1-2bf0e099d19c
# ╟─43a25dc8-6574-11eb-3607-311aa8d5451e
# ╟─5eafd0f0-6619-11eb-355d-f9de3ae53f6a
# ╟─b36832aa-64ab-11eb-308a-8f031686c8d6
# ╟─7ed6b942-695f-11eb-38a1-e79655aedfa2
# ╟─c8f92204-64ac-11eb-0734-2df58e3373e8
# ╟─2f9f008a-64aa-11eb-0d9a-0fdfc41d4657
# ╠═b8d874b6-648d-11eb-251c-636c5ebc1f42
# ╠═f48fa122-649a-11eb-2041-bbf0d0c4670c
# ╟─10dd6814-f796-42ea-8d40-287ed7c9d239
# ╠═8ddb6f1e-649e-11eb-3982-83d2d319b31f
# ╠═61a36e78-57f8-4ef0-83b4-90e5952c116f
# ╠═ffe07e00-0408-4986-9205-0fbb025a698c
# ╠═5d11a2df-3187-4509-ba7b-8388564573a6
# ╠═f4c62f95-876d-4915-8372-258dfde835f7
# ╟─50d9fb56-64af-11eb-06b8-eb56903084e2
# ╟─9302b00c-656f-11eb-25b3-495ae1c843cc
# ╠═3aeb0106-661b-11eb-362f-6b9af20f71d7
# ╠═8d4cb5dc-6573-11eb-29c8-81baa6e3fffc
# ╠═6e38d4db-e3ba-4b37-8f3e-c9f9359efa89
# ╟─d6694c32-656c-11eb-0796-5f485cccccf0
# ╟─ce75fe16-6570-11eb-3f3a-577eac7f9ee8
# ╟─37972f08-db05-4e84-9528-fe16cd86efbf
# ╟─f4cd5fb2-6574-11eb-37c4-73d4b21c1883
# ╟─1bd2c660-6572-11eb-268c-732fd2210a58
# ╠═f8bfd21a-60eb-4293-bc66-89b194608be5
# ╟─0b35f73f-6976-4d85-b61f-b4188440043e
# ╟─2fd3fa39-5314-443c-a690-bf27de93e479
# ╟─78e729f8-ac7d-43c5-ad93-c07d9ac7f30e
# ╠═49b21e4e-6577-11eb-38b2-45d30b0f9c80
# ╠═7b43d3d6-03a0-4e0b-96e2-9de420d3187f
# ╟─c5f48079-f52e-4134-8e6e-6cd4c9ee915d
# ╟─65df78ae-1533-4fad-835d-e301581d1c35
# ╟─9f040172-36bd-4e46-9827-e25c5c7fba12
# ╟─34b1a3ba-657d-11eb-17fc-5bf325945dce
# ╟─83b817d2-657d-11eb-3cd2-332a348142ea
# ╟─bb924b8e-69f9-11eb-1e4e-7f841ac1c1bd
# ╟─0d610e80-661e-11eb-3b9a-93af6b0ad5de
# ╟─e8b7861e-661c-11eb-1c06-bfedd6ab563f
# ╟─02b1e334-661d-11eb-3194-b382045810ef
# ╟─79f3c8b7-dea6-473c-87e5-772e391a51f4
# ╟─1f53eee1-c160-468f-93b3-d43a87a863ec
# ╠═3bf0f92a-991d-42d3-ad30-28fb0acb3269
# ╠═1e2189d3-58c5-4f7d-b76c-2e0ad5b7a803
# ╟─12d7647e-6a13-11eb-2b1e-9f77bdb3a87a
# ╟─98d449ac-695f-11eb-3daf-dffb377aa5e2
# ╟─b9c7df54-6a0c-11eb-1982-d7157b2c5b92
# ╟─8a2c223e-6960-11eb-3d8a-516474e6653c
# ╠═809375ba-6960-11eb-29d7-f9ab3ee61367
# ╟─dc9ac0c0-6a0a-11eb-2ca8-ada347bffa85
# ╟─945d67f6-6961-11eb-33cf-57ffe340b35f
# ╟─1be1ac8a-6961-11eb-2736-79c77025255d
# ╟─11c507a2-6a0f-11eb-35bf-55e1116a3c72
# ╟─48818cf0-6962-11eb-2024-8fca0690dd78
# ╟─fac414f6-6961-11eb-03bb-4f58826b0e61
# ╟─57a72310-69ef-11eb-251b-c5b8ab2c6082
# ╟─b92329ed-668d-46b0-9d21-65b04294cf83
# ╠═97b92593-b859-4553-b8d0-a8f3f1445df3
# ╟─6b93d1ab-ead5-4d3b-9d19-0d287611fbb6
# ╟─29036938-69f4-11eb-09c1-63a7a75de61d
# ╟─1978febe-657c-11eb-04ac-e19b2d0e5a85
# ╠═18e84a22-69ff-11eb-3909-7fd30fcf3040
# ╟─0d2b1bdc-6a14-11eb-340a-3535d7bfbec1
# ╟─eacde133-b154-4a09-b582-84d59dda3984
# ╠═655dcc5d-9b81-4734-ba83-1b0570bed8e4
# ╟─3c83862c-3603-4f85-9a57-89e662b250df
# ╠═dceb5318-69fc-11eb-2e1b-0b8cef279e05
# ╟─da82d3ea-69f6-11eb-343f-a30cdc36228a
# ╟─00bd3b6a-19de-4edd-82c3-9c57b4de64f1
# ╟─a81600e1-6b52-460c-808f-a785989bd4a6
# ╟─515edb16-69f3-11eb-0bc9-a3504565b80b
# ╟─deb1435b-6267-40a9-8f94-b3491c0f1c6b
# ╟─d18f1b0c-69ee-11eb-2fc0-4f14873847fb
# ╠═1abd6992-6962-11eb-3db0-f3dbe5f095eb
# ╠═07c102c2-69ee-11eb-3b29-25e612df6911
# ╟─74c35594-69f0-11eb-015e-2bf4b55e658c
# ╠═6ffb63bc-69f0-11eb-3f84-d3fca5526a3e
# ╟─1b8c26b6-64aa-11eb-2d9a-47db5469a654
# ╟─07a66c72-6576-11eb-26f3-810607ca7e51
# ╠═ca77fa78-657a-11eb-0faf-15ffd3fdc540
# ╠═fecf62c5-2c1d-4709-8c17-d4b6e0565617
# ╠═208445c4-5359-4442-9b9b-bde5e55a8c23
# ╟─e4d016cc-64ae-11eb-1ca2-259e5a262f33
# ╠═c112f585-489a-4feb-bc12-0122738f9f33
# ╠═bf18bef2-649d-11eb-3e3c-45b41a3fa6e5
# ╠═11ea4b84-649c-11eb-00a4-d93af0bd31c8
# ╠═b0d34450-6497-11eb-01e3-27582a9f1dcc
# ╠═63b2882e-649b-11eb-28de-bd418b43a35f
# ╟─47ac6d3c-6556-11eb-209d-f7a8219512ee
# ╠═5c3a80d2-6db3-4b3b-bc06-55a64e0cac6e
# ╠═db7eec4a-11b6-42b7-9070-e92500496d74
# ╠═b4707854-88fb-4285-b6b8-6360edd2ccf7
# ╠═28202f93-8f14-4a54-8389-40093c1fe9cf
# ╠═c511f396-6579-11eb-18b1-df745093a116
# ╠═67e74a32-6578-11eb-245c-07894c89cc7c
# ╠═51a16fcc-6556-11eb-16cc-71a978e02ef0
# ╠═f6f71c0e-6553-11eb-1a6a-c96f38c7f17b
# ╠═4a9b5d8a-64b3-11eb-0028-898635af227c
# ╟─e82d5b7f-5f37-4696-9917-58b117b9c1d6
# ╠═95b67e4d-5d41-4b86-bb9e-5de97f5d8957
# ╠═c1971734-2299-4038-8bb6-f62d020f92cb
# ╟─5fe4d47c-64b4-11eb-2a44-473ef5b19c6d
# ╠═66d78eb4-64b4-11eb-2d30-b9cee7370d2a
# ╟─a81f5244-64aa-11eb-1854-6dbb64c8eb6a
# ╠═fdf43912-6623-11eb-2e6a-137c10342f32
# ╠═db08e739-99f2-46a8-80c0-dadd8b2cadd1
# ╠═2305de0f-79ee-4377-9925-d6f861f2ee86
# ╠═a5c1da76-8cfc-45c0-a2d8-c20e96d78a03
# ╟─5872fda5-148c-4c4d-8127-eb882437c075
# ╠═ae30a71d-e152-4e2e-900b-76efe94d55cf
# ╠═642e0095-21f1-444e-a733-1345c7b5e1cc
# ╠═98d4da42-a067-4918-beb0-93147e9f5f7d
# ╠═159ebefa-49b0-44f6-bb96-5ab816b3fc98
# ╠═5f2782dd-390c-4ebf-8dfe-6b24fdc7c844
# ╟─7f57095f-88c5-4d65-b758-3bc928ea8d76
# ╠═cf30ace3-1c08-4ef3-8986-a27df7f1799d
# ╠═c03fbf6b-436f-4a9b-b0e1-830e1b7849b7
# ╠═b6c688d0-5954-4f9b-a559-ad28a585c651
# ╠═6607dac5-83fa-4d5f-9c8f-8c0c4706d01a
# ╟─17989c8e-ff35-4900-bb0c-63298a87e3fb
# ╠═e0bfd39a-a5c5-47be-a4f4-ffba3779f8ac
# ╠═c178b435-98ac-4366-b4c9-d57b5be13897
# ╟─bed07322-64b1-11eb-3324-7b7ac5e8fba2
# ╠═31bbc540-68cd-4d4a-b87a-d648e003524c
# ╠═21dfdec3-db5f-40d7-a59e-b1c323a69fc8
# ╠═ff0608aa-4653-430c-a050-f7a987c5d520
# ╠═54db603a-2751-425d-8e76-b9d0048869bf
# ╠═d994b4c2-0e64-4d4b-b526-a876b4e0b0e3
# ╠═5cc16d98-a809-4276-8b17-2e858e8ec42a
# ╠═259a640c-73cf-4694-8bd2-da3f4dbdb2ce
# ╠═989dd65c-c598-4dfc-9099-6f986847aa52
# ╠═7740e8e6-2063-4d9d-9c07-b7c164cf3310
# ╟─96f5a53b-72ab-44db-b8f3-37ceb802bf1a
# ╟─7e754b5f-0078-43e7-b0ca-eaef2fcf3e53
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
