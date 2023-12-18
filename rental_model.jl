include("rental_model_params.jl")

@agent TenantAgent GridAgent{2} begin
    income::Float64
    beyondMeans::Bool
    cutoffMeans::Bool
    relocating::Bool
end

@agent LandlordAgent GridAgent{2} begin
    rent::Float64
    greed::Float64
    bracket::String
    vacancy::Bool
end


############################ INITIALIZE MODEL ##############################

# fucntion to initialize the model
function generate_biased_random_values(num_values, range_low, range_high, target, weight)
    # Calculate mean and standard deviation based on concentration factor
    mean_value = target
    std_deviation = (range_high - range_low) / weight
    
    # Create a truncated normal distribution
    distribution = Truncated(Normal(mean_value, std_deviation), range_low, range_high)
    
    # Generate random values
    random_values = rand(distribution, num_values)
    
    return random_values    
end

function randomize_value(original_value, range)
    randomized_value = original_value + rand(rentalModel.rng) * 2 * range - range
    return randomized_value
end

function distribute_values(arrayLow, counterLow, arrayMid, counterMid, arrayHigh, counterHigh, group)
    value = nothing
    if group == 1 && counterLow <= length(arrayLow)
        value = arrayLow[counterLow]
        counterLow += 1
    elseif group == 1 && counterMid <= length(arrayMid)
        value = arrayMid[counterMid]
        counterMid += 1
    elseif group == 1 && counterHigh <= length(arrayHigh)
        value = arrayHigh[counterHigh]
        counterHigh += 1
    end
    
    if group == 2 && counterMid <= length(arrayMid)
        value = arrayMid[counterMid]
        counterMid += 1
    elseif group == 2 && counterLow <= length(arrayLow)
        value = arrayLow[counterLow]
        counterLow += 1
    elseif group == 2 && counterHigh <= length(arrayHigh)
        value = arrayHigh[counterHigh]
        counterHigh += 1
    end
    
    if group == 3 && counterHigh <= length(arrayHigh)
        value = arrayHigh[counterHigh]
        counterHigh += 1
    elseif group == 3 && counterLow <= length(arrayLow)
        value = arrayLow[counterLow]
        counterLow += 1
    elseif group == 3 && counterMid <= length(arrayMid)
        value = arrayMid[counterMid]
        counterMid += 1
    end
    return Dict(:value => value, :counterLow => counterLow, :counterMid => counterMid, :counterHigh => counterHigh)
end

function agent_swap!(agent1, agent2, model)
    savePos = agent1.pos
    move_agent!(agent1, agent2.pos, model)
    move_agent!(agent2, savePos, model)
end

function sort_and_shuffle_rent(rentArrayRaw)
    # sort raw rent values and return 3D array re shuffled
    rentArrayRaw = sort(rentArrayRaw)
    #find indexes to split the array
    lowIndex = Int(ceil(length(rentArrayRaw) * 0.33))
    midIndex = Int(ceil(length(rentArrayRaw) * 0.67))

    # split the Array and put it in a Dict
    return Dict(
        :low => shuffle(rentArrayRaw[1:lowIndex]),
        :mid => shuffle(rentArrayRaw[lowIndex + 1:midIndex]),
        :high => shuffle(rentArrayRaw[midIndex + 1:end])
    )
end

function create_tenant_agent(model, pos, income)
    # beyondMeans and relocating always false on creation
    # They will be updated later in itterat_rent_model
   return TenantAgent(nextid(model), pos, income, false, false, false)
end

function rental_model_initialize(; total_rentals = 15000, griddims = (200, 120), seed = 150)
    global dataYear
    global TENANT_SHUFFLE_PROBABILITY_INIT
    global LANDLORD_GREED_VARIABILITY

    space = GridSpace(griddims, periodic = false)
    properties = Dict(
        :background => schellingModel.properties[:background],
        :rentAverage => data["yearlyData"][dataYear]["rentPrice"]["average"],
        :rentTrueAverage => 0,
        :rentIncreaseOccupied => 0,
        :rentAverageVacant => 0,
        :rentIncreaseVacant => 0,
        :newRentalNum => 0,
        :evictionNumber => 0,
        :evictionArray => [],
        :relocationCounter => 0,
        :relocationMinimum => 0,
        # Array with only incomes. every element represent a tenant waiting to get a rental
        :newTenantArray => [],
        :homelessCount => 0,
        :tenantChangeCityCount => 0,
        :vacancyRate => 3.9
    )

    rng = Random.Xoshiro(seed)

    model = ABM(
        Union{TenantAgent, LandlordAgent}, space;
        properties, rng, scheduler = Schedulers.Randomly(), warn = false #warn about the use of Union{}
    )

    # populate the model with tenants

    # generate income values
    incomeData = data["yearlyData"][dataYear]["income"]
    # total number of tenants multiplied by the percentage with low, mid or high income
    numLowTenants = Int(round((length(schellingModel.agents) * percent(incomeData["low"]))))
    numMidTenants = Int(round(length(schellingModel.agents) * percent(incomeData["mid"])))
    numHighTenants = Int(round(length(schellingModel.agents) - numLowTenants - numMidTenants))

    arrayLow = generate_biased_random_values(
        numLowTenants,
        10000,
        20000,
        incomeData["lowTargetValue"],
        incomeData["lowWeight"]
    ) 
    arrayMid = generate_biased_random_values(
        numMidTenants,
        20001,
        60000,
        incomeData["midTargetValue"],
        incomeData["midWeight"]
    ) 
    arrayHigh = generate_biased_random_values(
        numHighTenants,
        60001,
        100000,
        incomeData["highTargetValue"],
        incomeData["highWeight"]
    ) 

    numberOfAgentsToRemove = total_rentals * percent(data["yearlyData"][dataYear]["vacancyRate"])
    # random_array = lower_limit .+ rand(1:upper_limit, array_size)
    vacantRentalArray = 1 .+ rand(1:total_rentals, Int(round(numberOfAgentsToRemove)))
    counterLow = 1
    counterMid = 1
    counterHigh = 1

    for i in 1:total_rentals 
        #skip if tenant was picked in vacantRentalArray
        if i in vacantRentalArray
            continue
        end

    
        #add tenants and give them an income based on their location
        result = distribute_values(arrayLow, counterLow, arrayMid, counterMid, arrayHigh, counterHigh, schellingModel.agents[i].group)

        income = result[:value]

        counterLow = result[:counterLow]
        counterMid = result[:counterMid]
        counterHigh = result[:counterHigh]

        pos = schellingModel.agents[i].pos
        beyondMeans = false
        agent = create_tenant_agent(model, pos, income)
        add_agent!(agent, pos, model)
    end

    # swap a fixed initial amount of tenants
    # Right now, it's swaping about 1500 tenants
    for i in 1:length(model.agents)
        r = rand(model.rng)
        if r < TENANT_SHUFFLE_PROBABILITY_INIT
            r = rand(1:length(model.agents))
            while r == i
                r = rand(1:length(model.agents))
            end
            agent_swap!(model.agents[i], model.agents[r], model)    
        end
    end

    # add landlord agents
    rentData = data["yearlyData"][dataYear]["rentPrice"]
    # genrerate rent prices based on year average with max variability up and down
    rentArrayRaw = generate_biased_random_values(
        length(schellingModel.agents),
        rentData["average"] - rentData["average"] * percent(rentData["rentVariabilityDown"]),
        rentData["average"] + rentData["average"] * percent(rentData["rentVariabilityUp"]),
        rentData["average"],
        rentData["rentWeight"]
    )

    rentArrays = sort_and_shuffle_rent(rentArrayRaw)

    counterLow = 1
    counterMid = 1
    counterHigh = 1

    greedArray = generate_biased_random_values(length(schellingModel.agents), 0, 1, 0.5, LANDLORD_GREED_VARIABILITY)

    for i in 1:length(schellingModel.agents)
        # calculate rent
        result = distribute_values(rentArrays[:low], counterLow, rentArrays[:mid], counterMid, rentArrays[:high], counterHigh, schellingModel.agents[i].group)

        rent = result[:value]

        counterLow = result[:counterLow]
        counterMid = result[:counterMid]
        counterHigh = result[:counterHigh]

        # level of greed
        greed = greedArray[i]
        #don't forget the associated bracket "low", "mid" or "high"
        if schellingModel.agents[i].group == 1
            bracket = "low"
        elseif schellingModel.agents[i].group == 2
            bracket = "mid"
        else
            bracket = "high"
        end


        pos = schellingModel.agents[i].pos

        # placeholder before updating vacancy
        vacancy = false
        
        # add the landlord agents
        agent = LandlordAgent(nextid(model), pos, rent, greed, bracket, vacancy)
        add_agent!(agent, pos, model)
    end

    # update tenant beyondMeans

    # update vacancy


    return model
end

rentalModel = rental_model_initialize(; 
    total_rentals = length(schellingModel.agents),
    griddims = (gridSize.x, gridSize.y),
    seed = seed
)


######################### GETTERS AND SETTERS #################################
# setters usually finish with "!"

function get_landlord(tenantAgent::TenantAgent, model)
    agents = collect(agents_in_position(tenantAgent, model))
    for a in agents
        if typeof(a) != TenantAgent
            return a
        end
    end
end

function get_landlords(model)
    landlords = []
    for a in allagents(model)
        if typeof(a) == LandlordAgent
            push!(landlords, a)
        end
    end
    return landlords
end

function get_tenants(model)
    tenants = []
    for a in allagents(model)
        if typeof(a) == TenantAgent
            push!(tenants, a)
        end
    end
    return tenants
end

function get_tenant(landlordAgent::LandlordAgent, model)
    agents = collect(agents_in_position(landlordAgent, model))
    for a in agents
        if typeof(a) != LandlordAgent
            return a
        end
    end
    return nothing
end

function get_tenant_number(model)
    counter = 0
    for a in allagents(model)
       if typeof(a) == TenantAgent 
        counter += 1
       end
    end
    return counter
end

function set_rent_true_average!(model)
    totalRent = 0
    counter = 0
    for a in allagents(model)
        if typeof(a) == LandlordAgent
            totalRent += a.rent
            counter += 1
        end
    end
    return totalRent / counter
end

function get_vacancy_rate(model)
    totalRentals = length(get_landlords(model))
    vacantRental = 0
    for a in allagents(model)
        if typeof(a) == LandlordAgent
            ids = ids_in_position(a.pos, model)
            if length(ids) == 1
                vacantRental += 1
            end
        end
    end
    return vacantRental / totalRentals * 100
    # totalRentals = 0
    # vacantRental = 0
    # for a in allagents(model)
    #     if typeof(a) == LandlordAgent
    #         if a.vacancy
    #             vacantRental += 1
    #         end
    #         totalRentals += 1
    #     end
    # end
    # return vacantRental / totalRentals * 100
end

function get_rentals_with_multiple_tenants(model)
    count = 0
    for a in allagents(model)
        if typeof(a) == LandlordAgent
            ids = ids_in_position(a.pos, model)
            if length(ids) > 2
                count += 1
            end
        end
    end
end

# get number of tenants to evict according to the vacancy vacancy
# maping according to the RCLALC: LA HAUSSE ALARMANTE DES ÉVICTIONS FORCÉES AU QUÉBEC
# 0.5% - 15% -> 4000 eviction - 250 eviction
function get_eviction_number(model)
    vacancyRate = get_vacancy_rate(rentalModel)
    #for testing this is set to round and it gives about 1 eviction for the initial vacancy rate and 150 landlords (it could be set to "floor" in order to reduce the amount a bit)
    
    # return number of eviction
    return Int(round(map_range(vacancyRate, VACANCY_RATE_RANGE[1], VACANCY_RATE_RANGE[2], 4000 * percent(fractionCoeficient), 250 * percent(fractionCoeficient))))
end

function get_new_rental_number(model)
    rentalNum = length(get_landlords(model))
    return Int(round( rentalNum * percent(randomize_value(RENTAL_PERCENT_INCREASE, RENTAL_PERCENT_INCREASE_RANGE))))
end

function get_new_tenant_number(model)
    # This is my own interpretation!
    # lower vacancy rate => less people moving in
    # !This is not backed by research at the moment!
    vacancyRate = get_vacancy_rate(rentalModel)
    
    # return number of new tenants
    return Int(round(percent(
        Int(round(map_range(
            vacancyRate,
            VACANCY_RATE_RANGE[1],
            VACANCY_RATE_RANGE[2],
            TENANT_POP_INCREASE - TENANT_POP_INCREASE_RANGE,
            TENANT_POP_INCREASE + TENANT_POP_INCREASE_RANGE
        )
    ))) * length(get_tenants(model))))
end

function get_empty_grid_space(model)
    # trust that only one landlord per GridSpace
    totalGridSpace = size(model.space)[1] * size(model.space)[2]
    totalLandlord = length(get_landlords(model))
    return totalGridSpace - totalLandlord
end

function get_positions(model)
    positions = []
    for a in allagents(model)
        if typeof(a) == LandlordAgent
            push!(positions, a.pos)
        end
    end
    return positions
end

function get_empty_positions(model)
    all_positions = [(i, j) for i in 1:size(model.space)[1] for j in 1:size(model.space)[2]]  # Adjust grid size as needed
    occupied_positions = get_positions(model)
    empty_positions = setdiff(all_positions, occupied_positions)
    return empty_positions
end

function get_relocating_tenants(model)
    tenants = []
    for a in allagents(model)
        if typeof(a) == TenantAgent
            if a.relocating
                push!(tenants, a)
            end
        end
    end
    return tenants
end

function tenant_beyondMeans!(tenantAgent::TenantAgent, model)
    landlord = get_landlord(tenantAgent, model)
    if tenantAgent.income * percent(data["beyondMeans%"]) < landlord.rent * 12
        tenantAgent.beyondMeans = true
        if tenantAgent.income * percent(CUTOFF_MEANS) < landlord.rent * 12
            tenantAgent.cutoffMeans = true
        end
    else
        tenantAgent.beyondMeans = false
        tenantAgent.cutoffMeans = false
    end
end

# update the values of beyondMeans for tenant and Vacancy for landlord
function update_vacancy(model)
    for a in allagents(model)
        if typeof(a) == LandlordAgent
            tenant = get_tenant(a, model)
            if tenant === nothing
                a.vacancy = true
            else
                # Also update to vacant if tenant is about to move
                if tenant.relocating
                    a.vacancy = true
                else
                    a.vacancy = false
                end
            end
        end
    end
end

function get_vacant_rentals(model)
    vacantRentals = []
    for a in allagents(model)
        if typeof(a) == LandlordAgent
            # if a.vacancy
            #     push!(vacantRentals, a)
            # end
            if get_tenant(a, model) === nothing
                push!(vacantRentals, a)
            end
        end
    end
    return vacantRentals
end

function get_vacancy_rentals(model)
    vacantRentals = []
    for a in allagents(model)
        if typeof(a) == LandlordAgent
            if a.vacancy
                push!(vacantRentals, a)
            end
        end
    end
    return vacantRentals
end

function get_non_vacant_rentals(model)
    nonVacantRentals = []
    for a in allagents(model)
        if typeof(a) == LandlordAgent
            if get_tenant(a, model) !== nothing
                push!(nonVacantRentals, a)
            end
        end
    end
    return nonVacantRentals
end

function remove_landlord_from_array(landlords, pos_to_remove)
    return filter(landlord -> landlord.pos != pos_to_remove, landlords)
end

function move_tenant!(id, newPos, income, new, model)
    if new
        agent = create_tenant_agent(model, newPos, income)
        add_agent!(agent, newPos, model)
    else
        move_agent!(model.agents[id], newPos, model)
        model.agents[id].relocating = false
    end
end

function sort_by_bracket_and_shuffle(landlordArray)
    low(agent) = occursin("low", agent.bracket)
    mid(agent) = occursin("mid", agent.bracket)
    high(agent) = occursin("high", agent.bracket)

    array = []
    push!(array, filter(high, landlordArray))
    push!(array, filter(mid, landlordArray))
    push!(array, filter(low, landlordArray))

    returnArray = []
    for a in array
        if length(a) > 0
            push!(returnArray, shuffle(a))
        end
    end
    return returnArray
end

function update_beyondMeans(model)
    for a in allagents(model)
        # update the beyondMeans for each tenant
        if typeof(a) == TenantAgent
            tenant_beyondMeans!(a, model)
        end
    end
end

function weighted_sample(elements::Vector{Any}, num_samples::Int)
    ids = [e.id for e in elements]
    weights = [e.greed for e in elements]  # Use greed values as weights

    # replace false allows for not selecting the same element twice
    selected_ids = sample(ids, Weights(weights), num_samples, replace=false)

    return selected_ids
end

function get_new_rent_vacant(amount_rent, model)
    return generate_biased_random_values(
        amount_rent,
        model.properties[:rentAverageVacant] - model.properties[:rentAverageVacant] * percent(RENT_INCREASE_VARIABILITY_VACANT.down),
        model.properties[:rentAverageVacant]+ model.properties[:rentAverageVacant] * percent(RENT_INCREASE_VARIABILITY_VACANT.up),
        model.properties[:rentAverageVacant],
        RENT_INCREASE_VARIABILITY_VACANT.weight
    )
end

function get_new_rent_vacant(model)
    return generate_biased_random_values(
        1,
        model.properties[:rentAverageVacant] - model.properties[:rentAverageVacant] * percent(RENT_INCREASE_VARIABILITY_VACANT.down),
        model.properties[:rentAverageVacant]+ model.properties[:rentAverageVacant] * percent(RENT_INCREASE_VARIABILITY_VACANT.up),
        model.properties[:rentAverageVacant],
        RENT_INCREASE_VARIABILITY_VACANT.weight
    )[1]
end

function rental_count_neighboring_agents(pos, model)
    global gridSize
    count_neighbor = 0
    neighbors = []
    if pos[1] != gridSize.x
       push!(neighbors, ids_in_position((pos[1] + 1, pos[2]), model))
    end
    if pos[1] != gridSize.x && pos[2] != gridSize.y
       push!(neighbors, ids_in_position((pos[1] + 1, pos[2] + 1), model))
    end
    if pos[1] != gridSize.x && pos[2] != 1
       push!(neighbors, ids_in_position((pos[1] + 1, pos[2] - 1), model))
    end
    if pos[1] != 1
       push!(neighbors, ids_in_position((pos[1] - 1, pos[2]), model))
    end
    if pos[1] != 1 && pos[2] != gridSize.y
       push!(neighbors, ids_in_position((pos[1] - 1, pos[2] + 1), model))
    end
    if pos[1] != 1 && pos[2] != 1
       push!(neighbors, ids_in_position((pos[1] - 1, pos[2] - 1), model))
    end
    if pos[2] != gridSize.y
       push!(neighbors, ids_in_position((pos[1], pos[2] + 1), model))
    end
    if pos[2] != 1
       push!(neighbors, ids_in_position((pos[1], pos[2] - 1), model))
    end
    
    for neighbor in neighbors
        if length(neighbor) != 0
            count_neighbor += 1
        end
    end

    return count_neighbor
end

# update background color
function rental_background_step!(model)
    global gridSize
    gridColor = 0

    # itterate throughh the whole grid (grid = Matrix)
    for i in 1:gridSize.x
        for j in 1:gridSize.y
            agentId = model.space.stored_ids[i, j]
            if length(agentId) != 0
                if length(agentId) > 1
                    for id in agentId
                        if typeof(model.agents[id]) == LandlordAgent
                            agentId = id
                        end
                    end
                elseif typeof(agentId[1]) == TenantAgent
                    continue
                else
                    agentId = agentId[1]
                end
                # if there is an agent on the space
                agent = model.agents[agentId]
                if agent.bracket == "high"
                    gridColor = 3
                elseif agent.bracket == "mid"
                    gridColor = 2
                else
                    gridcolor = 1
                end
                count_neighbors_same_group = 0
                for neighbor in nearby_agents(agent, model)
                    if typeof(neighbor) == LandlordAgent
                        neighbor.bracket == agent.bracket ? count_neighbors_same_group += 1 : nothing
                    end
                    # count_neighbors_same_group += 1
                end
                colorVariation = map_range(count_neighbors_same_group, 0, 8, -0.5, 0)
                gridColor += colorVariation
            else
                # if there's no agent on the space
                neighborCount = rental_count_neighboring_agents((i, j), model)
                colorVariation = map_range(neighborCount, 0, 8, 0, 2)
                gridColor = colorVariation
            end
            # update the value of background
            model.properties[:background][i, j] = gridColor
        end
    end
end

# Do it ounce for the initial model
update_vacancy(rentalModel)
update_beyondMeans(rentalModel)

# ########################## STEPPING THE MODEL #############################

function initial_model_step!(model)
    model.properties[:tenantChangeCityCount] = 0
    model.properties[:newRentalNum] = 0

    # update eviction number and create a random Array using greed value
    model.properties[:evictionNumber] = get_eviction_number(model)
    model.properties[:evictionArray] = weighted_sample(get_non_vacant_rentals(model), model.properties[:evictionNumber])

    # update relocationMinimum and counter
    model.properties[:relocationCounter] = 0
    model.properties[:relocationMinimum] = get_tenant_number(model) * percent(RELOCATION_MINIMUM)

    # update occupied rent increase rate
    model.properties[:rentIncreaseOccupied] = randomize_value(RENT_INCREASE_AVERAGE_OCCUPIED, 0.5)

    # update vacant rent average
    model.properties[:rentIncreaseVacant] = map_range(
        get_vacancy_rate(model),
        VACANCY_RATE_RANGE[1],
        VACANCY_RATE_RANGE[2],
        RENT_INCREASE_VACANT_MAX,
        0
        )

    # update occupied rent price average
    # "+ 1" cause i multiply by the percentage increase and want the increased value
    model.properties[:rentAverage] *= (percent(model.properties[:rentIncreaseOccupied]) + 1)

    # update vacant rent price average
    model.properties[:rentAverageVacant] = model.properties[:rentAverage] * (percent(model.properties[:rentIncreaseVacant]) + 1)

    # add new rentals
    if get_empty_grid_space(model) > 0
        # add rentals if there is gridSpace
        newRentalNum = get_new_rental_number(model)
        model.properties[:newRentalNum] = newRentalNum

        rentArrayRaw = get_new_rent_vacant(newRentalNum, model)
        
        greedArray = generate_biased_random_values(newRentalNum, 0, 1, 0.5, LANDLORD_GREED_VARIABILITY)

        if newRentalNum > 0
            for i in 1:newRentalNum
                emptyPos = get_empty_positions(model)
                if length(emptyPos) > 0
                    pos = rand(model.rng, emptyPos)
                    agent = LandlordAgent(nextid(model), pos, rentArrayRaw[i], greedArray[i], "high", true)
                    add_agent!(agent, pos, model)
                    # Example without pos!
                    # add_agent!(LandlordAgent, model, pos, rentArrayRaw[i], greedArray[i], "high", true)
                else
                    println("NO MORE EMPTY POSITIONS")
                end
            end
        end
    end
    
    # return number of new tenants
    # change TENANT_POP_INCREASE to vary this amount
    newTenantNum = get_new_tenant_number(model)
    # Income will be decided according to the rentAverageVacant and a range +/-
    # average vacant rent * 12 month / 30% == average yearly salary to rent affordably
    # Change NEW_TENANT_INCOME_RANGE_PERCENT to affect this
    model.properties[:newTenantArray] = []
    if newTenantNum > 0
        for i in 1:newTenantNum
            newIncomeAvergae = model.properties[:rentAverageVacant] * 12 / 0.3
            income = randomize_value(newIncomeAvergae, newIncomeAvergae * percent(NEW_TENANT_INCOME_RANGE_PERCENT))
            # push in newTenantArray
            push!(model.properties[:newTenantArray], income)
        end
    end
end

# I don't think I need this here!
# model_step!(rentalModel)

function landlord_step!(landlord::LandlordAgent, model)
    # Evict tenants if decided in evictionArray
    evictionArray = model.properties[:evictionArray] 
    if length(evictionArray) > 0
        for id in evictionArray
            if landlord.id == id
                # println("Evicting tenant with rental ID ", id, " landlord:")
                # println(landlord)
                
                # Notify the tenant that they will need to move 
                ids = ids_in_position(landlord.pos, model)
                if length(ids) > 1
                    # println("A tenant is there, so notifying the tenant.")
                    for tenant_id in ids
                        if tenant_id != landlord.id
                            # println("Notifying tenant with ID ", tenant_id)
                            tenant = model.agents[tenant_id]
                            
                            # Tell the tenant they will need to move!
                            tenant.relocating = true
                            # println("here is the tenant:")
                            # println(tenant)
                            
                            # Fix the rent with the vacancy price!
                            model.agents[landlord.id].rent = get_new_rent_vacant(model)
                            # println("new rent: ", model.agents[landlord.id].rent)
                            # println()
                        end
                    end
                else
                    println("trying to Evicting a vacant rental.\n")
                end
            end
        end
    end

    # increase rent!
    if landlord.vacancy
        # increase following market if vacant, get_new_rent_vacant() is an
        # overloaded function. When calling it with only model it return one value
        # with a range, it returns an array
        landlord.rent = get_new_rent_vacant(model)
    else
        landlord.rent *= (percent(model.properties[:rentIncreaseOccupied]) + 1)
    end
end

function tenant_decide!(tenant::TenantAgent, model)
    # Increase income
    tenant.income *= percent(randomize_value(INCOME_INCREASE, INCOME_INCREASE_RANGE)) + 1
    #println("Income increased to: ", tenant.income)

    # Decide to move
    relocatingFlag = false
    r = rand(model.rng)
    #println("Random value for relocation decision: ", r)
    
    if tenant.cutoffMeans
        #println("Tenant is relocating due to cutoffMeans.")
        relocatingFlag = true
    elseif tenant.beyondMeans
        if r < percent(CHANCE_MOVING_BEYOND_MEANS)
            #println("Tenant is relocating beyond means.")
            r = rand(model.rng)
            if r < percent(CHANCE_TO_CHANGE_CITY)
                #println("Deleting agent as chance to change city is met.")
                # Delete Agent
                model.properties[:tenantChangeCityCount] += 1
                remove_agent!(tenant, model)
            else
                #println("Tenant is relocating.")
                relocatingFlag = true 
            end
        end
    else
        if r < percent(CHANCE_MOVING)
            #println("Tenant is relocating.")
            r = rand(model.rng)
            if r < percent(CHANCE_TO_CHANGE_CITY)
                #println("Deleting agent as chance to change city is met.")
                # Delete Agent
                model.properties[:tenantChangeCityCount] += 1
                remove_agent!(tenant, model)
            else
                #println("Tenant is relocating.")
                relocatingFlag = true
            end
        end
    end

    if relocatingFlag
        tenant.relocating = true
        # this trigger can be switched to false and simulate a very crude version where the governemt keeps track of rents maybe
        # right now, landlords up the rents as soon as a tenant moves out
        if (CESSION_TRIGGER)
            # increase rent!
            landlord = get_landlord(tenant, model)
            landlord.rent = get_new_rent_vacant(model)
        end
    end
end

function tenant_move!(model)
    relocatingTenants = get_relocating_tenants(model)
    tenants_moving = []
    agentsToRemove = []
    for a in relocatingTenants
        # [ID, nextPos, income, Bool::New?]
        # at first nextPos is only pos or (1, 1) as placeholder before being updated
        push!(tenants_moving, [a.id, a.pos, a.income, false])
    end
    if length(model.properties[:newTenantArray]) > 0
        newTenants = []
        id = nextid(model)
        for a in model.properties[:newTenantArray]
            push!(newTenants, [id, (1, 1), a, true])
            id += 1
        end
        append!(tenants_moving, newTenants)
        println("relocating tenants and new ones: ", length(tenants_moving))
    end

    # get vacant rentals
    vacantRentals = get_vacancy_rentals(model)
    for a in tenants_moving
        if length(vacantRentals) > 0
            # filter for affordability i.e. less than 30% of income
            rentMax = a[3] * percent(data["beyondMeans%"]) / 12
            filteredRentals = filter(vacantRental -> vacantRental.rent <= rentMax, vacantRentals)
            if length(filteredRentals) > 0
                vacantRentalsSorted = sort_by_bracket_and_shuffle(filteredRentals)
                # chose first pos of shuffled arrays high are first, after mid and low
                newPos = vacantRentalsSorted[1][1].pos 
                a[2] = newPos
                vacantRentals = remove_landlord_from_array(vacantRentals, newPos)
                move_tenant!(a[1], a[2], a[3], a[4], model)
                continue
            end

            # if hasn't found check for shitty rentals under cutoffMeans
            rentMin = rentMax
            rentMax = a[3] * percent(CUTOFF_MEANS) / 12
            filteredRentals = filter(vacantRental -> rentMin <= vacantRental.rent <= rentMax, vacantRentals)
            if length(filteredRentals) > 0
                vacantRentalsSorted = sort_by_bracket_and_shuffle(filteredRentals)
                # chose first pos of shuffled arrays high are first, after mid and low
                newPos = vacantRentalsSorted[1][1].pos 
                a[2] = newPos
                vacantRentals = remove_landlord_from_array(vacantRentals, newPos)
                move_tenant!(a[1], a[2], a[3], a[4], model)
                continue
            end

            # Getting to this point means that the tenant has not found a rental
            #check if new agent or not
            if a[4]
                # just update homeless
                model.properties[:homelessCount] += 1
            else
                model.properties[:homelessCount] += 1
                push!(agentsToRemove, a)
                # remove_agent!(model.agents[a[1]], model)
            end
        end
    end
    for a in agentsToRemove
        remove_agent!(a[1], model)
    end
end

function agent_step!(agent, model)
    # empty because I'm doing a custom scheduler...
    # I hope it works lol
end

function whole_model_step!(model)
    initial_model_step!(model)

    for a in allagents(model)
        if typeof(a) == LandlordAgent
            landlord_step!(a, model)
        end
    end

    for a in allagents(model)
        if typeof(a) == TenantAgent
            tenant_decide!(a, model)
        end
    end

    # Update to allow for moving tenants
    update_vacancy(model)

    tenant_move!(model)

    # update beyondMeans and Vacancy after itteration and before displaying!
    update_vacancy(model)
    update_beyondMeans(model)
    rental_background_step!(model)

    model.properties[:rentTrueAverage] = set_rent_true_average!(model)

    println("num new tenants: ", length(model.properties[:newTenantArray]))
    println("num new rentals: ", model.properties[:newRentalNum])
    rate = get_vacancy_rate(model)
    println("vacancy rate: ", rate)
    model.properties[:vacancyRate] = rate
    println("rent average: ", model.properties[:rentTrueAverage])
    println(model.properties[:homelessCount], " total 'homeless'")
    println("num agent change city: ", model.properties[:tenantChangeCityCount])
    println("num multi tenant: ", get_rentals_with_multiple_tenants(model))

    println()
    println("next Itteration:")
    println()
end

function itterate_rent_model(model, itteration::Int64)
    for i in 1:itteration
        step!(model, agent_step!, whole_model_step!)
    end
end
