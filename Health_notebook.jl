### A Pluto.jl notebook ###
# v0.14.0

using Markdown
using InteractiveUtils

# This Pluto notebook uses @bind for interactivity. When running this notebook outside of Pluto, the following 'mock version' of @bind gives bound variables a default value (instead of an error).
macro bind(def, element)
    quote
        local el = $(esc(element))
        global $(esc(def)) = Core.applicable(Base.get, el) ? Base.get(el) : missing
        el
    end
end

# ╔═╡ 0189cd8a-f034-4c20-8571-14fb5da873e7
begin
    import Pkg
    # activate a clean environment
    Pkg.activate(mktempdir())

    Pkg.add([
        Pkg.PackageSpec(name="PlutoUI"),
        Pkg.PackageSpec(name="DataFrames"),
		Pkg.PackageSpec(name="CSV"),
		Pkg.PackageSpec(name="Query"),
		Pkg.PackageSpec(name="VegaLite"),
		Pkg.PackageSpec(name="Dates"),
		Pkg.PackageSpec(name="HTTP")			
        ])

    using PlutoUI, DataFrames, CSV, Query, VegaLite, Dates, HTTP
end

# ╔═╡ 8268035c-aaf7-4811-b858-20161b57a0b9
md"## Visualizing Samsung Health App Data"

# ╔═╡ c5aa61e2-06b9-4bb6-819f-b0043d5bf932
md" > **Demo notebook for PlutoCon 2021**
>
> **Author: Vikas Negi**
>
> [LinkedIn] (https://www.linkedin.com/in/negivikas/)
"

# ╔═╡ f656c150-eeb8-4eb7-8c8f-48f213d14a88
md"
### Introduction
---

In this notebook, we will analyze my activity data obtained via the Samsung Health app. The data is recorded by sensors present in the: 1) Galaxy S9+ phone - steps, distance (via a pedometer) and (2) Gear S3 Frontier watch - steps, distance, climbed floors, and heart rate (via a photoplethysmogram). Data are available in the form of .csv files, which makes them quite easy to use.

We will read the data directly from my github repository using **CSV.jl**, and store them in the form of DataFrames. For visualization, we will make use of the excellent **VegaLite.jl** package.
"

# ╔═╡ 2c49defa-0695-4974-8154-9f9688108a51
md"
### Obtaining input data
---

If you use the Samsung Health app, you can download the activity data by following the instructions as described in this [article](https://towardsdatascience.com/extract-health-data-from-your-samsung-96b8a2e31978). I guess Fitbit and Garmin users can also use a similar strategy.


URL to the files have been added below. They are read directly into a DataFrame. We set **header = 2** so that the second row is used to name the columns in our DataFrame.
"

# ╔═╡ ffacf8a1-0750-48bd-880b-6c42014a7351
begin
	
	url_pedometer = "https://raw.githubusercontent.com/vnegi10/Health_data_analysis/master/data/com.samsung.shealth.tracker.pedometer_day_summary.202104030009.csv"	
	
	df_pedometer_raw = CSV.File(HTTP.get(url_pedometer).body, header = 2) |> DataFrame
	
	url_heart_rate = "https://raw.githubusercontent.com/vnegi10/Health_data_analysis/master/data/com.samsung.shealth.tracker.heart_rate.202104030009.csv"
	
	df_heart_raw = CSV.File(HTTP.get(url_heart_rate).body, header = 2) |> DataFrame
	
	url_floors = "https://raw.githubusercontent.com/vnegi10/Health_data_analysis/master/data/com.samsung.health.floors_climbed.202104030009.csv"
	
	df_floors_raw = CSV.File(HTTP.get(url_floors).body, header = 2) |> DataFrame
	
end

# ╔═╡ 8a38cbad-5684-4a8e-91fc-b38f787cd5e1
md"
### Exploring the structure of our DataFrame
---
"

# ╔═╡ bd5ffe99-b7ce-4883-9198-73391a71e695
# Check size of the DataFrame

size(df_pedometer_raw)

# ╔═╡ 824b9f5f-2b7c-414c-9aea-5a6877732139
# Check various statistics about the DataFrame

describe(df_pedometer_raw)

# ╔═╡ e83af676-3745-49fe-aa9c-e66fc3e2ef28
md"
### Clean and organize the data
---
"

# ╔═╡ eb1dc392-eb58-4034-8784-0a8ef79c4ff0
begin
	# Create an independent copy
	df_pedometer = deepcopy(df_pedometer_raw)
	
	# Set format for the DateTime object
	datef = dateformat"y-m-d H:M:S.s"
	
	# Convert create_time column from string into DateTime objects
	df_pedometer[!, :create_time] = DateTime.(df_pedometer_raw[!, :create_time], datef)
	
	# Convert distance into km and time into minutes
	df_pedometer[!, :distance] = df_pedometer_raw[!, :distance]/1000  # to km
	df_pedometer[!, :active_time] = df_pedometer[!, :active_time]/60000 # to minutes
	
	# Remove rows which have type 'missing' in the source_info column, this gets rid 	   of duplicates. @dropna macro comes from Query.jl
	df_pedometer = df_pedometer |> @dropna(:source_info) |> DataFrame
	
	# Sort the DataFrame in the order of increasing time
	sort!(df_pedometer, :create_time)
end

# ╔═╡ b7dd0336-2dad-4c0c-b934-eb9d235b658d
md"
### Calculate cumulative distance, add it to a new column
---
"

# ╔═╡ 6fa76290-bb8b-4b96-b54f-c68e1c699a4a
# Calculate cumulative distance and add a new column to the existing DataFrame
begin
	    cumul_distance = Float64[]
	    day_type, day, month, year = (Any[] for i = 1:4)	    
	    
		for i = 1:size(df_pedometer)[1]
			push!(cumul_distance, sum(df_pedometer[!, :distance][1:i]))
		    push!(day, Dates.dayname(df_pedometer[!, :create_time][i]))
		    push!(month, Dates.monthname(df_pedometer[!, :create_time][i]))
		    push!(year, Dates.year(df_pedometer[!, :create_time][i]))
		    if Dates.dayname(df_pedometer[!, :create_time][i]) in ["Saturday", "Sunday"]
				push!(day_type, "weekend")
			else
				push!(day_type, "weekday")
			end			
		end
	    insertcols!(df_pedometer, 1, :cumul_distance => cumul_distance, :day_type => 					day_type, :day => day, :month => month, :year => year)	    
end

# ╔═╡ 7b11af41-9d7e-425d-9517-1914165967bd
md"
### Select time range to plot activity data
---
"

# ╔═╡ 15e32715-bfc8-4228-b7f8-9abac314a610
md" **Select start date**"

# ╔═╡ 277c7460-788f-4b93-b1d2-b4d4e4d0a14d
@bind start_date DateField()

# ╔═╡ 7f427cfc-e21b-413b-821f-6f0d86954f1c
md" **Select end date**"

# ╔═╡ dc3696c2-479b-4aa9-9552-bd858f475c2b
@bind end_date DateField()

# ╔═╡ 0e27122a-f517-458a-a3de-ad4f6a0cbc60
md" DataFrame is filtered based on the time range selected above. **@filter** is a powerful macro provided by the Query.jl package. We filter out rows for which `create_time` lies between `start_date` and `end_date`.
"

# ╔═╡ a5ea4203-08eb-4afd-ab36-564482274ec3
df_pedometer_filter = df_pedometer |> 

@filter(_.create_time > start_date &&  _.create_time < end_date) |> DataFrame

# ╔═╡ c552099a-9025-4297-8825-a4242559122d
md"
### Daily steps in a given time period
---

Our filtered DataFrame `df_pedometer_filter` can be passed directly to **@vlplot** macro provided by the VegaLite.jl package. Rest of the arguments are specific to the type of plot. Check out the [VegaLite.jl](https://www.queryverse.org/VegaLite.jl/stable/gettingstarted/tutorial/) tutorial.
"

# ╔═╡ 9339dde8-2b00-406c-9fc4-ba34c4d8579c
df_pedometer_filter |> @vlplot("mark"={:area, "line" = {"color" = "seagreen"},
        				"color"={"x1"=1, "y1"=1, "x2"=1, "y2"=0,
           				 "gradient"=:linear, "stops" = [
               			 {"offset"=0, "color"="white"},
                		 {"offset"=1, "color"="green"}]}}, 
	x = {:create_time, "axis" = {"title" = "Time", "labelFontSize" = 12, "titleFontSize" = 14}, "type" = "temporal"}, 
	y = {:step_count, "axis" = {"title" = "Daily steps", "labelFontSize" = 12, "titleFontSize" = 14 }}, 
	width = 750, height = 500, 
	"title" = {"text" = "Daily steps from $(Date.(start_date)) to $(Date.(end_date))", "fontSize" = 16})

# ╔═╡ 5dc6a5f9-4ddb-4d57-87b7-df3e23155c56
md" We can plot a histogram to see the distribution of steps between different years. Looking at data for 2020 vs 2019, it is clear that I have done less steps in 2020. This is likely due to the Corona situation.
"

# ╔═╡ 00712037-2c82-4fd2-9777-e49d313e54fa
df_pedometer_filter |> 

@vlplot(:bar, 
	x = {:step_count, "axis" = {"title" = "Number of steps", "labelFontSize" = 12, "titleFontSize" = 14}, "bin" = {"maxbins" = 50}}, 
	y = {"count()", "axis" = {"title" = "Number of counts", "labelFontSize" = 12, "titleFontSize" = 14 }}, 
	width = 850, height = 500, 
	"title" = {"text" = "Step count distribution from $(Date.(start_date)) to $(Date.(end_date))", "fontSize" = 16},
	color = :year)

# ╔═╡ 7998fa73-c5f8-4497-8b8f-8c43222773d9
md" 
### Monthly breakdown between different years
---
"

# ╔═╡ 41194cce-6f90-4404-827b-a24d3546dff0
df_pedometer_filter |> 

@vlplot(:bar, 
	column = "month:o",
	x = {"year:n", "axis" = {"title" = "Year", "labelFontSize" = 12, "titleFontSize" = 14}}, 
	y = {"sum(step_count)", "axis" = {"title" = "Number of steps", "labelFontSize" = 12, "titleFontSize" = 14, "grid" = false}}, 
	
	"title" = {"text" = "Monthly breakdown of step count from $(Date.(start_date)) to $(Date.(end_date))", "fontSize" = 16},
	color={"year:n", scale={range=["#675193", "#ca8861"]}},
	spacing = 10, config={view={stroke=:transparent}, axis={domainWidth=1}})

# ╔═╡ fe15cdda-3128-4a7f-be92-58cad62c5007
md"
### Daily distance in a given time period
---

Setting the color scale to `:distance` column in our DataFrame, renders the bars with a gradient that is proportional to the size of each data point. Looks quite cool!
"

# ╔═╡ 19a9837e-db8e-4ff4-9f75-1c6f5ad9fc74
df_pedometer_filter |> 

@vlplot("mark"={:bar, "width" = 3}, 
	x = {:create_time, "axis" = {"title" = "Time", "labelFontSize" = 12, "titleFontSize" = 14}, "type" = "temporal"}, 
	y = {:distance, "axis" = {"title" = "Daily distance [km]", "labelFontSize" = 12, "titleFontSize" = 14 }}, 
	width = 850, height = 500, 
	"title" = {"text" = "Daily distance from $(Date.(start_date)) to $(Date.(end_date))", "fontSize" = 16},
	color = :distance)

# ╔═╡ 4a5c4d8a-1d5d-4458-885a-2658d9328489
md"
### Cumulative distance for the selected time period
---
"

# ╔═╡ 22081464-abb6-4157-98bc-80c361144105
df_pedometer_filter |> 

@vlplot(:area, 
	x = {:create_time, "axis" = {"title" = "Time", "labelFontSize" = 12, "titleFontSize" = 14}, "type" = "temporal"}, 
	y = {:cumul_distance, "axis" = {"title" = "Aggregate daily distance [km]", "labelFontSize" = 12, "titleFontSize" = 14 }}, 
	width = 850, height = 500, 
	"title" = {"text" = "Cumulative distance from $(Date.(start_date)) to $(Date.(end_date))", "fontSize" = 16},
	)

# ╔═╡ 0b0dc862-a8f4-4bc8-b5fd-50e74c221bc5
md"
### Distribution of active time for the selected time period
---
"

# ╔═╡ 61f017e1-ea63-4d6d-aedc-25d943871975
df_pedometer_filter |> 

@vlplot(:bar, 
	x = {:active_time, "axis" = {"title" = "Measured active time [minutes]", "labelFontSize" = 12, "titleFontSize" = 14}, "bin" = {"maxbins" = 50}}, 
	y = {"count()", "axis" = {"title" = "Number of counts", "labelFontSize" = 12, "titleFontSize" = 14 }}, 
	width = 850, height = 500, 
	"title" = {"text" = "Active time distribution from $(Date.(start_date)) to $(Date.(end_date))", "fontSize" = 16},
	color = :day_type)

# ╔═╡ f74a93fb-6c1b-4080-b40c-5fc4590b6125
md" I appear to be quite active on Wednesdays, that is surprising!"

# ╔═╡ 2389995c-1758-4d91-baf7-d3e0dcf7ce85
df_pedometer_filter |> 

@vlplot(:bar, 
	x = {:active_time, "axis" = {"title" = "Measured active time [minutes]", "labelFontSize" = 12, "titleFontSize" = 14}, "bin" = {"maxbins" = 50}}, 
	y = {"count()", "axis" = {"title" = "Number of counts", "labelFontSize" = 12, "titleFontSize" = 14 }}, 
	width = 850, height = 500, 
	"title" = {"text" = "Active time distribution from $(Date.(start_date)) to $(Date.(end_date))", "fontSize" = 16},
	color = :day)

# ╔═╡ 007192c1-a745-4ced-8af4-c320c8e44181
md"
### Correlation between number of steps and calories
---

As expected, number of steps and total calories consumed have a direct correlation. This 2D histogram scatterplot also shows markers with size proportional to the total number of counts. Fewer data points exist for higher step counts. I should try to be more active this year!
"

# ╔═╡ 3d63542e-5a51-4368-85e5-2e0be17ae991
df_pedometer_filter |> 

@vlplot(:circle, 
	x = {:step_count, "axis" = {"title" = "Number of steps", "labelFontSize" = 14, "titleFontSize" = 14}, "bin" = {"maxbins" = 30}}, 
	y = {:calorie, "axis" = {"title" = "Calories", "labelFontSize" = 14, "titleFontSize" = 14 }, "bin" = {"maxbins" = 30}}, 
	width = 850, height = 500, 
	"title" = {"text" = "2D histogram scatterplot calories vs step count from $(Date.(start_date)) to $(Date.(end_date))", "fontSize" = 16},
	size = "count()")

# ╔═╡ c24250e2-5d8f-464a-8c33-48d165242163
md"
### Visualizing heart rate data
---
"

# ╔═╡ 54e3fa06-f672-404e-bcdd-c414846df0f9
size(df_heart_raw)

# ╔═╡ 2180887e-ff4b-4a22-be86-00c6cd72a285
# Same as before 
begin
	df_heart = deepcopy(df_heart_raw)
	
	# Rename columns to a shorter and more readable name
	rename!(df_heart, Dict(Symbol("com.samsung.health.heart_rate.create_time") => "create_time", Symbol("com.samsung.health.heart_rate.heart_rate") => "heart_rate"))
	
	df_heart[!, :create_time] = DateTime.(df_heart[!, :create_time], datef)
	sort!(df_heart, :create_time);
end

# ╔═╡ 612fb369-0149-4090-ac2f-37a4926a1293
df_heart_filter = df_heart |> @filter(_.create_time > start_date &&  _.create_time < end_date) |> DataFrame

# ╔═╡ b7e5fe84-e455-4b71-aba6-1b5927eed45e
md"
### Scatter plot of heart rate data for selected time period
---
"

# ╔═╡ f35989fa-903c-4d79-9cbc-59ab4ff9ff2f
df_heart_filter |> 

@vlplot(:circle, 
	x = {:create_time, "axis" = {"title" = "Time", "labelFontSize" = 12, "titleFontSize" = 14}, "type" = "temporal"}, 
	y = {:heart_rate, "axis" = {"title" = "Measured heart rate [bpm]", "labelFontSize" = 12, "titleFontSize" = 14 }}, 
	width = 850, height = 500, 
	"title" = {"text" = "Heart rate from $(Date.(start_date)) to $(Date.(end_date))", "fontSize" = 16},
	size = :heart_rate)

# ╔═╡ ce3f3eb8-a7d0-4b05-942a-ec4bf1df5a6f
md"
### Show heart rate distribution for the selected time period
---

Heart rate is measured by my watch every 10 minutes. I wear it almost everyday. That means most of the data points are collected while I am sitting (mostly relaxed) at my desk for work. Data appears to be clustered around the resting heart rate range of 60-100 beats per minute. That's a relief!
"

# ╔═╡ d2789f5e-3642-4a39-9776-60959c553990
df_heart_filter |> 

@vlplot(:bar, 
	x = {:heart_rate, "axis" = {"title" = "Measured heart rate [bpm]", "labelFontSize" = 12, "titleFontSize" = 14}}, 
	y = {"count()", "axis" = {"title" = "Number of counts", "labelFontSize" = 12, "titleFontSize" = 14 }}, 
	width = 850, height = 500, 
	"title" = {"text" = "Heart rate distribution from $(Date.(start_date)) to $(Date.(end_date))", "fontSize" = 16},
	color = :heart_rate)

# ╔═╡ d8ad02a1-c0e7-47d7-8814-3d4f994c953c
md"
### Visualize climbed floors data
---
"

# ╔═╡ bd47dea3-3ad4-41d0-9104-81cf2bce8ad8
begin
	df_floors = deepcopy(df_floors_raw)
	df_floors[!, :create_time] = DateTime.(df_floors[!, :create_time], datef)
	sort!(df_floors, :create_time)	
end

# ╔═╡ ec0fd3dc-a7ae-4331-af9b-2a547441befa
md"
### Number of floors climbed over the selected time range
---

Nothing too exciting here, except for a huge spike in Nov, 2019. I was wearing this watch during a short hike in the city of Nainital, India. An elevation change of 9 feet is recorded as one floor climb. So, 65 floors indicates that I must have climbed 585 feet ~ 178 m during that time. Phew!
"

# ╔═╡ 7167ce6d-1b77-48e6-ad78-a8082b87b8eb
df_floors |> 

@filter(_.create_time > start_date &&  _.create_time < end_date) |> 

@vlplot(:bar, 
	x = {:create_time, "axis" = {"title" = "Time", "labelFontSize" = 12, "titleFontSize" = 14}}, 
	y = {:floor, "axis" = {"title" = "Number of floors", "labelFontSize" = 12, "titleFontSize" = 14 }}, 
	width = 850, height = 500, 
	"title" = {"text" = "Floors climbed from $(Date.(start_date)) to $(Date.(end_date))", "fontSize" = 16})

# ╔═╡ Cell order:
# ╟─8268035c-aaf7-4811-b858-20161b57a0b9
# ╟─c5aa61e2-06b9-4bb6-819f-b0043d5bf932
# ╟─f656c150-eeb8-4eb7-8c8f-48f213d14a88
# ╟─0189cd8a-f034-4c20-8571-14fb5da873e7
# ╟─2c49defa-0695-4974-8154-9f9688108a51
# ╠═ffacf8a1-0750-48bd-880b-6c42014a7351
# ╟─8a38cbad-5684-4a8e-91fc-b38f787cd5e1
# ╠═bd5ffe99-b7ce-4883-9198-73391a71e695
# ╠═824b9f5f-2b7c-414c-9aea-5a6877732139
# ╟─e83af676-3745-49fe-aa9c-e66fc3e2ef28
# ╠═eb1dc392-eb58-4034-8784-0a8ef79c4ff0
# ╟─b7dd0336-2dad-4c0c-b934-eb9d235b658d
# ╠═6fa76290-bb8b-4b96-b54f-c68e1c699a4a
# ╟─7b11af41-9d7e-425d-9517-1914165967bd
# ╟─15e32715-bfc8-4228-b7f8-9abac314a610
# ╟─277c7460-788f-4b93-b1d2-b4d4e4d0a14d
# ╟─7f427cfc-e21b-413b-821f-6f0d86954f1c
# ╟─dc3696c2-479b-4aa9-9552-bd858f475c2b
# ╟─0e27122a-f517-458a-a3de-ad4f6a0cbc60
# ╠═a5ea4203-08eb-4afd-ab36-564482274ec3
# ╟─c552099a-9025-4297-8825-a4242559122d
# ╠═9339dde8-2b00-406c-9fc4-ba34c4d8579c
# ╟─5dc6a5f9-4ddb-4d57-87b7-df3e23155c56
# ╠═00712037-2c82-4fd2-9777-e49d313e54fa
# ╟─7998fa73-c5f8-4497-8b8f-8c43222773d9
# ╠═41194cce-6f90-4404-827b-a24d3546dff0
# ╟─fe15cdda-3128-4a7f-be92-58cad62c5007
# ╠═19a9837e-db8e-4ff4-9f75-1c6f5ad9fc74
# ╟─4a5c4d8a-1d5d-4458-885a-2658d9328489
# ╠═22081464-abb6-4157-98bc-80c361144105
# ╟─0b0dc862-a8f4-4bc8-b5fd-50e74c221bc5
# ╠═61f017e1-ea63-4d6d-aedc-25d943871975
# ╟─f74a93fb-6c1b-4080-b40c-5fc4590b6125
# ╠═2389995c-1758-4d91-baf7-d3e0dcf7ce85
# ╟─007192c1-a745-4ced-8af4-c320c8e44181
# ╠═3d63542e-5a51-4368-85e5-2e0be17ae991
# ╟─c24250e2-5d8f-464a-8c33-48d165242163
# ╠═54e3fa06-f672-404e-bcdd-c414846df0f9
# ╠═2180887e-ff4b-4a22-be86-00c6cd72a285
# ╠═612fb369-0149-4090-ac2f-37a4926a1293
# ╟─b7e5fe84-e455-4b71-aba6-1b5927eed45e
# ╠═f35989fa-903c-4d79-9cbc-59ab4ff9ff2f
# ╟─ce3f3eb8-a7d0-4b05-942a-ec4bf1df5a6f
# ╠═d2789f5e-3642-4a39-9776-60959c553990
# ╟─d8ad02a1-c0e7-47d7-8814-3d4f994c953c
# ╠═bd47dea3-3ad4-41d0-9104-81cf2bce8ad8
# ╟─ec0fd3dc-a7ae-4331-af9b-2a547441befa
# ╠═7167ce6d-1b77-48e6-ad78-a8082b87b8eb
