using Agents
using Random # for reproductibility
using Distributions #for value distribution
using StatsBase
using CairoMakie # choosing a plotting backend
using InteractiveDynamics
using GLMakie 
import Colors
using JSON
using Statistics: mean

# Loading data from data.json
# Specify the path to your JSON file
json_file_path = "data.json"

# Load JSON data from the file
json_data = read(json_file_path, String)

# Parse JSON data into a Julia dictionary
data = JSON.parse(json_data)
dataYear = "2016"

#global variables
gridSize = (x = 200, y = 120) #NamedTupple accesed with gridSize.x (immutable)
# gridSize = (x = 20, y = 10) #NamedTupple accesed with gridSize.x (immutable)
markerSizeValue = 5
# markerSizeValue = 50
# seed = rand(10:500)
seed = 150

# convert percent number to 0.X value
function percent(value)
    return value / 100
end

# SchellingParams
totalAgentsSchelling::Int64 = 15000
# this is a fraction of the real amount of rentals
# totalAgentsSchelling::Int64 = 150
fractionCoeficient = totalAgentsSchelling / data["yearlyData"][dataYear]["numLogement"] * 100
# envrion 3.04%

schellingMinToBeHappy = 4
schellingItterations = 150

#include files after global declaration in order for them to be accessible
include("schelling_model.jl")

function markerColor(a)
    # global rentalModel
    if a isa TenantAgent
        if a.beyondMeans
            return :red
        else
            return :gray45
        end
    else
        return :transparent
    end
end

markerShape(a) = a isa TenantAgent ? :rect : :rect

function markerSize(a)
    global markerSizeValue
    if a isa LandlordAgent
        if a.vacancy
            return markerSizeValue
        else
            return 0
        end
    else
        return markerSizeValue
    end
end

function getBackgroundArray(model)
    model.properties[:background]
end

set_theme!(backgroundcolor = :black)


plotkwargs = (
    ac = markerColor,
    am = markerShape,
    as = markerSize,
    heatarray = getBackgroundArray,
    scatterkwargs = (strokecolor = :gray90, strokewidth = 0.4),
    heatkwargs = (colormap = [:black, :gray38], colorrange = (0, 3)),
    add_colorbar = false
)


# display a model
function display_model(model, index)
    global plotkwargs 
    
    global figure, _ = Agents.abmplot(model; 
        plotkwargs...
    )
    screen = display(figure)  # Display the figure
    path = "images/render_1_" * string(index) * ".png"
    save(path, figure, resolution=(1600, 888))
    resize!(screen, 1600, 888)
end




# Call the function with the number of iterations you want
itterateSchelling(schellingItterations)

include("rental_model.jl")


for i in 1:60
    itterate_rent_model(rentalModel, 1)
    display_model(rentalModel, i)
end

# itterate_rent_model(rentalModel, 15)
# display_model(rentalModel)

# ################## Plotting graphs ##############
adata = []
get_average_rent(model) = model.properties[:rentTrueAverage]
get_vacancy_rate_data(model) = round(model.properties[:vacancyRate], digits=4)
# mdata = [get_average_rent]
mdata = [get_vacancy_rate_data]



function plot_rent_average(adf, mdf)
    global index
    figure = Figure(resolution = (1000, 750))
    ax = figure[1, 1] = Axis(
        figure;
        xlabel = "Année",
        ylabel = "Moy. Loyers",
        xlabelsize = 60,
        ylabelsize = 60,
        topspinecolor = :white,
        bottomspinecolor = :white,
        leftspinecolor = :white,
        rightspinecolor = :white,
        xgridcolor = :white,
        ygridcolor = :white,
        xtickcolor = :white,
        ytickcolor = :white,
        xticklabelsize = 60,
        yticklabelsize = 60,
        xlabelcolor = :white,
        ylabelcolor = :white,
        xticklabelcolor = :white,
        yticklabelcolor = :white,
        backgroundcolor = :black,
        xgridvisible = false,
        ygridvisible = false,
        xlabelvisible = false,
        ylabelvisible = false,
    )
    rent = lines!(ax, mdf.step, mdf.get_vacancy_rate_data, color = :red, linewidth = 10)


    path = "images/graph/vacancy_1_" * string(index) * ".png"
    save(path, figure, resolution=(1600, 888))
    figure
end

# index = 1
# for i in 1:60
#     rentalModel = rental_model_initialize(; 
#         total_rentals = length(schellingModel.agents),
#         griddims = (gridSize.x, gridSize.y),
#         seed = seed
#     )
#     adf, mdf = run!(rentalModel, agent_step!, whole_model_step!, i; adata, mdata)

#     plot_rent_average(adf, mdf)
#     global index += 1
# end

# ########### Interactive Model Tests #################

# getBackgroundArray(model) = model.properties[:background]
# figure, abmobs = abmplot(
#     rentalModel;
#     # agent_step! = agent_step!,
#     model_step! = whole_model_step!,
#     # params,
#     ac = markerColor,
#     am = markerShape,
#     as = markerSize,
#     heatarray = getBackgroundArray,
#     scatterkwargs = (strokecolor = :gray90, strokewidth = 0.4),
#     heatkwargs = (colormap = [:black, :gray38], colorrange = (0, 3)),
#     add_colorbar = false
#     # adata, alabels
# )
# display(figure)
