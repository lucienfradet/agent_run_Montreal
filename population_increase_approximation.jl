# From 2006 to predicted 2041
population = [1.87, 1.91, 1.96, 2.02, 2.19, 2.67]
# From 1986 to 2021
# population = [2.9, 3.2, 3.3, 3.4, 3.6, 3.8, 3.9, 4.1]

# Calculate percentage difference for each pair of consecutive years
percentage_differences = [(population[i+1] - population[i]) / population[i] * 100 for i in 1:length(population)-1]

# Display the results
for i in 1:length(percentage_differences)
    println("Percentage difference from year ", i, " to year ", i+1, ": ", percentage_differences[i], "%")
end
total = 0
for i in 1:length(percentage_differences)
    global total
    total += percentage_differences[i]
end
println(total/6)
# RESULT FOR PREDICTED (to 2041)
# 6.36% increase yearly
# 6.36 * 60% of montreal population in appartment = 3.82%

# RESULT FOR 1986 to 2021
# 4.23% increase