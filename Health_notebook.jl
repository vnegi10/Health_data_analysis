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
	using Pkg
	Pkg.activate(pwd())
	Pkg.instantiate
end

# ╔═╡ 792b96a6-9465-11eb-25cd-1bb88d739078
using PlutoUI, DataFrames, CSV, Query, VegaLite, Dates

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

We will directly read the data using **CSV.jl** and store them in the form of DataFrames. For visualization, we will make use of the excellent **VegaLite.jl** package.
"

# ╔═╡ 2c49defa-0695-4974-8154-9f9688108a51
md"
### Obtaining input data
---

If you use the Samsung Health app, you can download the activity data by following the instructions as described in this [article](https://towardsdatascience.com/extract-health-data-from-your-samsung-96b8a2e31978). I guess Fitbit and Garmin users will also have a way to access their own data.


Set path to the relevant .csv files. Name of the file indicates the type of content present within it.
"

# ╔═╡ ffacf8a1-0750-48bd-880b-6c42014a7351
begin
	data_folder = "samsunghealth_vikas.negi10_202104030009"	
	
	file_pedometer_day_summary = joinpath(data_folder, "com.samsung.shealth.tracker.pedometer_day_summary.202104030009.csv")
	
	file_heart_rate = joinpath(data_folder, "com.samsung.shealth.tracker.heart_rate.202104030009.csv")
	
	file_activity_day_summary = joinpath(data_folder, "com.samsung.health.floors_climbed.202104030009.csv")	
	
end

# ╔═╡ 6890f300-772b-4c9e-9e9d-406eb0610874
md"###### Parse .csv file, and store into a DataFrame. We want to have contents of row 2 from the input file as the column names of the resulting DataFrame."

# ╔═╡ db6f797b-63d3-4d6d-a768-54a12bf6cb3d
df_pedometer_raw = CSV.read(file_pedometer_day_summary, DataFrame, header = 2)

# ╔═╡ bd5ffe99-b7ce-4883-9198-73391a71e695
# Check size of the DataFrame

size(df_pedometer_raw)

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
md"##### Select time range to plot activity data"

# ╔═╡ 277c7460-788f-4b93-b1d2-b4d4e4d0a14d
@bind start_date DateField()

# ╔═╡ dc3696c2-479b-4aa9-9552-bd858f475c2b
@bind end_date DateField()

# ╔═╡ 0e27122a-f517-458a-a3de-ad4f6a0cbc60
md"##### Filter data based on time range selected using the sliders"

# ╔═╡ a5ea4203-08eb-4afd-ab36-564482274ec3
df_pedometer_filter = df_pedometer |> 

@filter(_.create_time > start_date &&  _.create_time < end_date) |> DataFrame

# ╔═╡ c552099a-9025-4297-8825-a4242559122d
md"##### Show daily steps in a given time period"

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

# ╔═╡ 00712037-2c82-4fd2-9777-e49d313e54fa
df_pedometer_filter |> 

@vlplot(:bar, 
	x = {:step_count, "axis" = {"title" = "Number of steps", "labelFontSize" = 12, "titleFontSize" = 14}, "bin" = {"maxbins" = 50}}, 
	y = {"count()", "axis" = {"title" = "Number of counts", "labelFontSize" = 12, "titleFontSize" = 14 }}, 
	width = 850, height = 500, 
	"title" = {"text" = "Step count distribution from $(Date.(start_date)) to $(Date.(end_date))", "fontSize" = 16},
	color = :year)

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
md"##### Show daily distance in a given time period"

# ╔═╡ 19a9837e-db8e-4ff4-9f75-1c6f5ad9fc74
df_pedometer_filter |> 

@vlplot("mark"={:bar, "width" = 3}, 
	x = {:create_time, "axis" = {"title" = "Time", "labelFontSize" = 12, "titleFontSize" = 14}, "type" = "temporal"}, 
	y = {:distance, "axis" = {"title" = "Daily distance [km]", "labelFontSize" = 12, "titleFontSize" = 14 }}, 
	width = 850, height = 500, 
	"title" = {"text" = "Daily distance from $(Date.(start_date)) to $(Date.(end_date))", "fontSize" = 16},
	color = :distance)

# ╔═╡ 4a5c4d8a-1d5d-4458-885a-2658d9328489
md"##### Show cumulative distance for the selected time period"

# ╔═╡ 22081464-abb6-4157-98bc-80c361144105
df_pedometer_filter |> 

@vlplot(:area, 
	x = {:create_time, "axis" = {"title" = "Time", "labelFontSize" = 12, "titleFontSize" = 14}, "type" = "temporal"}, 
	y = {:cumul_distance, "axis" = {"title" = "Aggregate daily distance [km]", "labelFontSize" = 12, "titleFontSize" = 14 }}, 
	width = 850, height = 500, 
	"title" = {"text" = "Cumulative distance from $(Date.(start_date)) to $(Date.(end_date))", "fontSize" = 16},
	)

# ╔═╡ 0b0dc862-a8f4-4bc8-b5fd-50e74c221bc5
md"##### Show distribution of active time (in mins) for the selected time period"

# ╔═╡ 61f017e1-ea63-4d6d-aedc-25d943871975
df_pedometer_filter |> 

@vlplot(:bar, 
	x = {:active_time, "axis" = {"title" = "Measured active time [minutes]", "labelFontSize" = 12, "titleFontSize" = 14}, "bin" = {"maxbins" = 50}}, 
	y = {"count()", "axis" = {"title" = "Number of counts", "labelFontSize" = 12, "titleFontSize" = 14 }}, 
	width = 850, height = 500, 
	"title" = {"text" = "Active time distribution from $(Date.(start_date)) to $(Date.(end_date))", "fontSize" = 16},
	color = :day_type)

# ╔═╡ 2389995c-1758-4d91-baf7-d3e0dcf7ce85
df_pedometer_filter |> 

@vlplot(:bar, 
	x = {:active_time, "axis" = {"title" = "Measured active time [minutes]", "labelFontSize" = 12, "titleFontSize" = 14}, "bin" = {"maxbins" = 50}}, 
	y = {"count()", "axis" = {"title" = "Number of counts", "labelFontSize" = 12, "titleFontSize" = 14 }}, 
	width = 850, height = 500, 
	"title" = {"text" = "Active time distribution from $(Date.(start_date)) to $(Date.(end_date))", "fontSize" = 16},
	color = :day)

# ╔═╡ 007192c1-a745-4ced-8af4-c320c8e44181
md"##### Show correlation between number of steps and calories"

# ╔═╡ 3d63542e-5a51-4368-85e5-2e0be17ae991
df_pedometer_filter |> 

@vlplot(:circle, 
	x = {:step_count, "axis" = {"title" = "Number of steps", "labelFontSize" = 14, "titleFontSize" = 14}, "bin" = {"maxbins" = 30}}, 
	y = {:calorie, "axis" = {"title" = "Calories", "labelFontSize" = 14, "titleFontSize" = 14 }, "bin" = {"maxbins" = 30}}, 
	width = 850, height = 500, 
	"title" = {"text" = "2D histogram scatterplot calories vs step count from $(Date.(start_date)) to $(Date.(end_date))", "fontSize" = 16},
	size = "count()")

# ╔═╡ c24250e2-5d8f-464a-8c33-48d165242163
md"##### Read file with heart rate data"

# ╔═╡ 0d746856-b0b3-49ce-9fbd-c8a1c8e6eba2
df_heart_raw = CSV.read(file_heart_rate, DataFrame, header = 2);

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
md"##### Show scatter plot of heart rate data for the selected time period"

# ╔═╡ f35989fa-903c-4d79-9cbc-59ab4ff9ff2f
df_heart_filter |> 

@vlplot(:circle, 
	x = {:create_time, "axis" = {"title" = "Time", "labelFontSize" = 12, "titleFontSize" = 14}, "type" = "temporal"}, 
	y = {:heart_rate, "axis" = {"title" = "Measured heart rate [bpm]", "labelFontSize" = 12, "titleFontSize" = 14 }}, 
	width = 850, height = 500, 
	"title" = {"text" = "Heart rate from $(Date.(start_date)) to $(Date.(end_date))", "fontSize" = 16},
	size = :heart_rate)

# ╔═╡ ce3f3eb8-a7d0-4b05-942a-ec4bf1df5a6f
md"##### Show heart rate distribution for the selected time period"

# ╔═╡ d2789f5e-3642-4a39-9776-60959c553990
df_heart_filter |> 

@vlplot(:bar, 
	x = {:heart_rate, "axis" = {"title" = "Measured heart rate [bpm]", "labelFontSize" = 12, "titleFontSize" = 14}}, 
	y = {"count()", "axis" = {"title" = "Number of counts", "labelFontSize" = 12, "titleFontSize" = 14 }}, 
	width = 850, height = 500, 
	"title" = {"text" = "Heart rate distribution from $(Date.(start_date)) to $(Date.(end_date))", "fontSize" = 16},
	color = :heart_rate)

# ╔═╡ d8ad02a1-c0e7-47d7-8814-3d4f994c953c
md"##### Read file with climbed floors data"

# ╔═╡ f2d80d3f-25e6-4248-b008-9f4b04d7e91f
df_floors_raw = CSV.read(file_floors, DataFrame, header = 2)

# ╔═╡ bd47dea3-3ad4-41d0-9104-81cf2bce8ad8
begin
	df_floors = deepcopy(df_floors_raw)
	df_floors[!, :create_time] = DateTime.(df_floors[!, :create_time], datef)
	sort!(df_floors, :create_time)	
end

# ╔═╡ ec0fd3dc-a7ae-4331-af9b-2a547441befa
md"##### Show number of floors climbed over the selected time range"

# ╔═╡ 7167ce6d-1b77-48e6-ad78-a8082b87b8eb
df_floors |> 

@filter(_.create_time > start_date &&  _.create_time < end_date) |> 

@vlplot(:bar, 
	x = {:create_time, "axis" = {"title" = "Time", "labelFontSize" = 12, "titleFontSize" = 14}}, 
	y = {:floor, "axis" = {"title" = "Number of floors", "labelFontSize" = 12, "titleFontSize" = 14 }}, 
	width = 850, height = 500, 
	"title" = {"text" = "Floors climbed from $(Date.(start_date)) to $(Date.(end_date))", "fontSize" = 16})

# ╔═╡ 848dad9c-6e34-406e-9dfa-de4a35c5e677


# ╔═╡ Cell order:
# ╟─8268035c-aaf7-4811-b858-20161b57a0b9
# ╟─c5aa61e2-06b9-4bb6-819f-b0043d5bf932
# ╟─f656c150-eeb8-4eb7-8c8f-48f213d14a88
# ╠═0189cd8a-f034-4c20-8571-14fb5da873e7
# ╠═792b96a6-9465-11eb-25cd-1bb88d739078
# ╟─2c49defa-0695-4974-8154-9f9688108a51
# ╠═ffacf8a1-0750-48bd-880b-6c42014a7351
# ╟─6890f300-772b-4c9e-9e9d-406eb0610874
# ╠═db6f797b-63d3-4d6d-a768-54a12bf6cb3d
# ╠═bd5ffe99-b7ce-4883-9198-73391a71e695
# ╟─eb1dc392-eb58-4034-8784-0a8ef79c4ff0
# ╟─6fa76290-bb8b-4b96-b54f-c68e1c699a4a
# ╟─7b11af41-9d7e-425d-9517-1914165967bd
# ╟─277c7460-788f-4b93-b1d2-b4d4e4d0a14d
# ╟─dc3696c2-479b-4aa9-9552-bd858f475c2b
# ╟─0e27122a-f517-458a-a3de-ad4f6a0cbc60
# ╠═a5ea4203-08eb-4afd-ab36-564482274ec3
# ╟─c552099a-9025-4297-8825-a4242559122d
# ╠═9339dde8-2b00-406c-9fc4-ba34c4d8579c
# ╠═00712037-2c82-4fd2-9777-e49d313e54fa
# ╠═41194cce-6f90-4404-827b-a24d3546dff0
# ╟─fe15cdda-3128-4a7f-be92-58cad62c5007
# ╠═19a9837e-db8e-4ff4-9f75-1c6f5ad9fc74
# ╟─4a5c4d8a-1d5d-4458-885a-2658d9328489
# ╠═22081464-abb6-4157-98bc-80c361144105
# ╟─0b0dc862-a8f4-4bc8-b5fd-50e74c221bc5
# ╠═61f017e1-ea63-4d6d-aedc-25d943871975
# ╠═2389995c-1758-4d91-baf7-d3e0dcf7ce85
# ╟─007192c1-a745-4ced-8af4-c320c8e44181
# ╠═3d63542e-5a51-4368-85e5-2e0be17ae991
# ╟─c24250e2-5d8f-464a-8c33-48d165242163
# ╠═0d746856-b0b3-49ce-9fbd-c8a1c8e6eba2
# ╠═54e3fa06-f672-404e-bcdd-c414846df0f9
# ╠═2180887e-ff4b-4a22-be86-00c6cd72a285
# ╠═612fb369-0149-4090-ac2f-37a4926a1293
# ╟─b7e5fe84-e455-4b71-aba6-1b5927eed45e
# ╠═f35989fa-903c-4d79-9cbc-59ab4ff9ff2f
# ╟─ce3f3eb8-a7d0-4b05-942a-ec4bf1df5a6f
# ╠═d2789f5e-3642-4a39-9776-60959c553990
# ╟─d8ad02a1-c0e7-47d7-8814-3d4f994c953c
# ╠═f2d80d3f-25e6-4248-b008-9f4b04d7e91f
# ╠═bd47dea3-3ad4-41d0-9104-81cf2bce8ad8
# ╟─ec0fd3dc-a7ae-4331-af9b-2a547441befa
# ╠═7167ce6d-1b77-48e6-ad78-a8082b87b8eb
# ╠═848dad9c-6e34-406e-9dfa-de4a35c5e677
