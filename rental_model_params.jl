# important tweaking params
TENANT_SHUFFLE_PROBABILITY_INIT = 0.1
LANDLORD_GREED_VARIABILITY = 8.0
RELOCATION_MINIMUM = 8

# For use in map_values function
# AN UPPER BOUND VALUE TO HIGH INCREASES EVERYTHING
# (I CALCULATE ALOT OF THINGS USING THIS RATE LOL)
VACANCY_RATE_RANGE = [0.5, 8]

# See population_increase_approximation.jl
# calcultated to be 3.82
TENANT_POP_INCREASE = 3.82

# substracted or added to the increase % to map these values to the vacancy rate
# !!!!!!!!!!!THERE MIGHT BE A PROBLEM WITH THIS
TENANT_POP_INCREASE_RANGE = 3

# 105100 logement * 60% des logement (locataires) sur 20 ans (2021 - 2041)
# 105100 * 0.6 / 20 = 3.15
RENTAL_NUM_INCREASE = 3.15
RENTAL_NUM_INCREASE_RANGE = 1.5
# OR using percentage
# originally 0.58
RENTAL_PERCENT_INCREASE = 0.58
RENTAL_PERCENT_INCREASE_RANGE = 0.08

# typical yearly rent increased allowed by régis du logement
RENT_INCREASE_AVERAGE_OCCUPIED = 3.0

# this is mapped to the vacancy rate
RENT_INCREASE_VACANT_MAX = 90

struct RentIncreaseVariabilityVacant{Any}
    up::Any
    down::Any
    weight::Any
end
RENT_INCREASE_VARIABILITY_VACANT = RentIncreaseVariabilityVacant{Any}(
    25,
    25,
    2.0
)

# percentage of difference a newly arrived tenant can have from the vacancyIncomeAverage
NEW_TENANT_INCOME_RANGE_PERCENT = 45

# Yealry income increase and variation range
INCOME_INCREASE = 1.6
INCOME_INCREASE_RANGE = 0.5

# percentage that the rent needs to be to obligate relocation
CUTOFF_MEANS = 75

# moving parameters
CHANCE_MOVING_BEYOND_MEANS = 35 # % chance to decide to move if beyond means
CHANCE_TO_CHANGE_CITY = 0.5 # % chance to move out if moving i.e. deleting the agent and not adding it to homelessCount
CHANCE_MOVING = 5 # % percent chance to move for "other" reasons

# landlords will always increase rents to maximum when tenants move
CESSION_TRIGGER = true


