#Create the basis for the simulation using Schelling model of segregation

# Declaring the agent(s)
@agent SchellingAgent GridAgent{2} begin
    mood::Bool # whether the agent is happy in its position. (true = happy)
    group::Int # The group of the agent, determines mood as it interacts with neighbors
end

# initialize model with a single function (Notice that the parameters are set in the function declaration) 
# It's actually parameters with names, they come after the ";"
function schelling_initialize(; total_agents = 320, griddims = (20, 20), min_to_be_happy = 4, seed = 125)
    global dataYear
    space = GridSpaceSingle(griddims, periodic = false)
    properties = Dict(:min_to_be_happy => min_to_be_happy, :background => fill(1.0, griddims))
    # Random seed! omg...
    rng = Random.Xoshiro(seed)
    # Schedulers is to control how every agent is activated at every step
    model = UnremovableABM(
        SchellingAgent, space;
        properties, rng, scheduler = Schedulers.Randomly()
    )
    # populate the model with agents, adding equal amount of the two types of agents
    # at random positions in the model
    for n in 1:total_agents

         # decide group
        group::Int8 = 0
        if (n < total_agents * percent(data["yearlyData"][dataYear]["tenantRatio"]["low"]))
            group = 1
        elseif (n < total_agents * percent(data["yearlyData"][dataYear]["tenantRatio"]["mid"]))
            group = 2
        else 
            group = 3
        end

        # includes if statement in the form of: <statement> ? <true> : <false>
        agent = SchellingAgent(n, (1, 1), false, group)
        add_agent_single!(agent, model)
    end
    return model
end

function schelling_agent_step!(agent, model)
    minHappy = model.min_to_be_happy
    count_neighbors_same_group = 0
    # For each neighbor, get group and compare to current agent's group
    # and increment `count_neighbors_same_group` as appropriately.
    # Here `nearby_agents` (with default arguments) will provide an iterator
    # over the nearby agents one grid point away, which are at most 8.
    for neighbor in nearby_agents(agent, model)
        if (agent.group == neighbor.group)
            count_neighbors_same_group += 1
    
        end
    end
    # After counting the neighbors, decide whether or not to move the agent.
    # If count_neighbors_same_group is at least the min_to_be_happy, set the
    # mood to true. Otherwise, move the agent to a random position, and set
    # mood to false.
    if count_neighbors_same_group ≥ minHappy
        agent.mood = true
    else
        agent.mood = false
        move_agent_single!(agent, model)
    end
    return
end

# Map value from rangeIn to rangeOut function
function map_range(x, in_min, in_max, out_min, out_max)
    if x < in_min
        return out_min
    elseif x > in_max
        return out_max
    else
        return out_min + (x - in_min) * (out_max - out_min) / (in_max - in_min)
    end
end

# Count neighbors from a specific position on the  grid. Very poorly designed function lol
function count_neighboring_agents(pos, model)
    global gridSize
    count_neighbor = 0
    stored_ids = model.space.stored_ids
    # Check for outof bounds errors manually
    if pos[1] != gridSize.x && stored_ids[pos[1] + 1, pos[2]] != 0
        count_neighbor += 1
    end
    if pos[1] != gridSize.x && pos[2] != gridSize.y && stored_ids[pos[1] + 1, pos[2] + 1] != 0
        count_neighbor += 1
    end
    if pos[1] != gridSize.x && pos[2] != 1 && stored_ids[pos[1] + 1, pos[2] - 1] != 0
        count_neighbor += 1
    end
    if pos[1] != 1 && stored_ids[pos[1] - 1, pos[2]] != 0
        count_neighbor += 1
    end
    if pos[1] != 1 && pos[2] != gridSize.y && stored_ids[pos[1] - 1, pos[2] + 1] != 0
        count_neighbor += 1
    end
    if pos[1] != 1 && pos[2] != 1 && stored_ids[pos[1] - 1, pos[2] - 1] != 0
        count_neighbor += 1
    end
    if pos[2] != gridSize.y && stored_ids[pos[1], pos[2] + 1] != 0
        count_neighbor += 1
    end
    if pos[2] != 1 && stored_ids[pos[1], pos[2] - 1] != 0
        count_neighbor += 1
    end
    return count_neighbor
end

# update background color
function background_step!(model)
    global gridSize

    # itterate throughh the whole grid (grid = Matrix)
    for i in 1:gridSize.x
        for j in 1:gridSize.y
            gridColor = 0
            agentId = model.space.stored_ids[i, j]
            if agentId != 0
                # if there is an agent on the space
                agent = model.agents[agentId]
                gridColor = agent.group
                count_neighbors_same_group = 0
                for neighbor in nearby_agents(agent, model)
                    count_neighbors_same_group += 1
                end
                colorVariation = map_range(count_neighbors_same_group, 0, 8, -0.5, 0)
                gridColor += colorVariation
            else
                # if there's no agent on the space
                neighbors = count_neighboring_agents((i, j), model)
                colorVariation = map_range(neighbors, 0, 8, 0, 2)
                gridColor = colorVariation
            end
            # update the value of background
            model.properties[:background][i, j] = gridColor
        end
    end
end

schellingModel = schelling_initialize(; total_agents = totalAgentsSchelling, griddims = (gridSize.x, gridSize.y), min_to_be_happy = schellingMinToBeHappy, seed = seed)

function schelling_model_step!(model)
    background_step!(model)
end

# itterate schelling model
function itterateSchelling(itterations::Int64)
   for i in 1:itterations
    step!(schellingModel, schelling_agent_step!, schelling_model_step!, 1) 
   end
end
