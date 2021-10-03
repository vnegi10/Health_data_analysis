### A Pluto.jl notebook ###
# v0.16.0

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
using PlutoUI, DataFrames, CSV, Query, VegaLite, Dates, HTTP, Statistics

# ╔═╡ 8268035c-aaf7-4811-b858-20161b57a0b9
md"## Visualizing Samsung Health App Data"

# ╔═╡ c5aa61e2-06b9-4bb6-819f-b0043d5bf932
md" > **Demo notebook for PlutoCon 2021**
>
> **Author: Vikas Negi**
>
> [LinkedIn] (https://www.linkedin.com/in/negivikas/)
"

# ╔═╡ bb24143d-9a1c-41c9-9328-40e4186dc86b
TableOfContents()

# ╔═╡ f656c150-eeb8-4eb7-8c8f-48f213d14a88
md"
## Introduction

In this notebook, we will analyze my activity data obtained via the Samsung Health app. The data is recorded by sensors present in my: 1) Galaxy S9+ phone - steps, distance (via a pedometer) and (2) Gear S3 Frontier watch - steps, distance, climbed floors, and heart rate (via a photoplethysmogram). Data are available in the form of .csv files, which makes them quite easy to use.

We will read the data directly from my github repository using **CSV.jl**, and store them in the form of DataFrames. For visualization, we will make use of the excellent **VegaLite.jl** package.
"

# ╔═╡ 68a82310-ea56-4c79-937d-fd3f12961617
md"
## Pkg environment

"

# ╔═╡ 2c49defa-0695-4974-8154-9f9688108a51
md"
## Obtaining input data


If you use the Samsung Health app, you can download the activity data by following the instructions as described in this [article](https://towardsdatascience.com/extract-health-data-from-your-samsung-96b8a2e31978). I guess Fitbit and Garmin users can also use a similar strategy.


URL to the files have been added below. They are read directly into a DataFrame. We set **header = 2** so that the second row is used to name the columns in our DataFrame.
"

# ╔═╡ ffacf8a1-0750-48bd-880b-6c42014a7351
begin
	
	# GitHub link	
	const URL = "https://raw.githubusercontent.com/vnegi10/Health_data_analysis/master/data"
	
	# CSV files from Samsung Health app	
	files = ["com.samsung.shealth.tracker.pedometer_day_summary.202110031456.csv", 
		     "com.samsung.shealth.tracker.heart_rate.202110031456.csv",
		     "com.samsung.health.floors_climbed.202110031456.csv"]	
	
	# Function to generate url	
	gen_url(file::String, url::String=URL) = joinpath(url, file)	
		
end

# ╔═╡ 5c1645d7-f51e-4f53-86ff-05b2e60865db
begin
	
	# Function to convert url to DataFrame	
	url_to_df(url::String) = CSV.File(HTTP.get(url, require_ssl_verification = false).body, header = 2) |> DataFrame
		
	df_pedometer_raw, df_heart_raw, df_floors_raw = [url_to_df(gen_url(file)) for file in files]
	
end

# ╔═╡ 8a38cbad-5684-4a8e-91fc-b38f787cd5e1
md"
## Exploring the structure of our DataFrame

"

# ╔═╡ 7bc8f218-01c5-4956-a156-82c6d5cb7d5b
df_pedometer_raw

# ╔═╡ bd5ffe99-b7ce-4883-9198-73391a71e695
# Check size of the DataFrame
size(df_pedometer_raw)

# ╔═╡ cc438ad3-da8b-4da6-9ccd-8dc47a098545
# Get column names
names(df_pedometer_raw)

# ╔═╡ 824b9f5f-2b7c-414c-9aea-5a6877732139
# Check various statistics about the DataFrame
describe(df_pedometer_raw)

# ╔═╡ e83af676-3745-49fe-aa9c-e66fc3e2ef28
md"
### Cleaning and organizing data
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
### Adding some new columns
---

We calculate the cumulative distance and add it to a separate column `cumul_distance`. For later use, it is also handy to classify days as 'weekday' or 'weekend', and add them to a separate `day_type` column. Similarly for `day` and `month` columns.
"

# ╔═╡ 6fa76290-bb8b-4b96-b54f-c68e1c699a4a
# Calculate cumulative distance and add a new column to the existing DataFrame
begin
	    cumul_distance = Float64[]
	    day_type, day, month = (String[] for i = 1:3)	 
	    year = Int64[]
	    
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
## Select time range to plot activity data


**Data is available between 05-2018 to 03-2021**
"

# ╔═╡ 15e32715-bfc8-4228-b7f8-9abac314a610
md" **Select start date**"

# ╔═╡ 277c7460-788f-4b93-b1d2-b4d4e4d0a14d
@bind start_date DateField(default = DateTime(2019,1,1))

# ╔═╡ 7f427cfc-e21b-413b-821f-6f0d86954f1c
md" **Select end date**"

# ╔═╡ dc3696c2-479b-4aa9-9552-bd858f475c2b
@bind end_date DateField(default = DateTime(2020,12,31))

# ╔═╡ 84fad772-b232-4e46-b219-be9fec0a979b


# ╔═╡ 0ce2c55e-af3b-4843-8abf-64876bdaff0b


# ╔═╡ 0e27122a-f517-458a-a3de-ad4f6a0cbc60
md" DataFrame is filtered based on the time range selected above. **@filter** is a powerful macro provided by the Query.jl package. We filter out rows for which `create_time` lies between `start_date` and `end_date`.
"

# ╔═╡ a5ea4203-08eb-4afd-ab36-564482274ec3
df_pedometer_filter = df_pedometer |> 

@filter(_.create_time > start_date &&  _.create_time < end_date) |> DataFrame

# ╔═╡ c552099a-9025-4297-8825-a4242559122d
md"
### Daily steps
---

Our filtered DataFrame `df_pedometer_filter` can be passed directly to **@vlplot** macro provided by the VegaLite.jl package. Rest of the arguments are specific to the type of plot. Check out the [VegaLite.jl](https://www.queryverse.org/VegaLite.jl/stable/gettingstarted/tutorial/) tutorial.
"

# ╔═╡ 9339dde8-2b00-406c-9fc4-ba34c4d8579c
figure1 = df_pedometer_filter |> @vlplot("mark"={:area, "line" = {"color" = "seagreen"},
        				"color"={"x1"=1, "y1"=1, "x2"=1, "y2"=0,
           				 "gradient"=:linear, "stops" = [
               			 {"offset"=0, "color"="white"},
                		 {"offset"=1, "color"="green"}]}}, 
	x = {:create_time, "axis" = {"title" = "Time", "labelFontSize" = 12, "titleFontSize" = 14}, "type" = "temporal"}, 
	y = {:step_count, "axis" = {"title" = "Daily steps", "labelFontSize" = 12, "titleFontSize" = 14 }}, 
	width = 750, height = 500, 
	"title" = {"text" = "Daily steps from $(Date.(start_date)) to $(Date.(end_date))", "fontSize" = 16})

# ╔═╡ d850b608-bfb2-4b02-89cb-f2af27417a28
save_fig(filename::String, figure::VegaLite.VLSpec) = save(joinpath("figures",filename), figure)

# ╔═╡ 5dc6a5f9-4ddb-4d57-87b7-df3e23155c56
md" We can plot a histogram to see the distribution of steps between different years. Looking at data for 2020 vs 2019, it is clear that I have done less steps in 2020. This is likely due to the Corona situation.
"

# ╔═╡ 03c531ee-7177-4cfd-811b-ab902212fcdd
md" **Change the number of max bins by dragging the slider below** "


# ╔═╡ d7146451-a459-48ca-878f-c75b874ccd21
@bind bins1 Slider(25:75, default=50, show_value=true)

# ╔═╡ 00712037-2c82-4fd2-9777-e49d313e54fa
figure2 = df_pedometer_filter |> 

@vlplot(:bar, 
	x = {:step_count, "axis" = {"title" = "Number of steps", "labelFontSize" = 12, "titleFontSize" = 14}, "bin" = {"maxbins" = bins1}}, 
	y = {"count()", "axis" = {"title" = "Number of counts", "labelFontSize" = 12, "titleFontSize" = 14 }}, 
	width = 850, height = 500, 
	"title" = {"text" = "Step count distribution from $(Date.(start_date)) to $(Date.(end_date))", "fontSize" = 16},
	color = "year:n")

# ╔═╡ beb86d06-2294-482d-9d00-a2c72986915a
save_fig("Daily_steps_hist.png", figure2)

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
### Daily distance
---

Setting the color scale to `:distance` column in our DataFrame, renders the bars with a gradient that is proportional to the size of each data point. Looks quite cool!
"

# ╔═╡ 19a9837e-db8e-4ff4-9f75-1c6f5ad9fc74
figure3 = df_pedometer_filter |> 

@vlplot("mark"={:bar, "width" = 3}, 
	x = {:create_time, "axis" = {"title" = "Time", "labelFontSize" = 12, "titleFontSize" = 14}, "type" = "temporal"}, 
	y = {:distance, "axis" = {"title" = "Daily distance [km]", "labelFontSize" = 12, "titleFontSize" = 14 }}, 
	width = 850, height = 500, 
	"title" = {"text" = "Daily distance from $(Date.(start_date)) to $(Date.(end_date))", "fontSize" = 16},
	color = :distance)

# ╔═╡ 8f1981a4-f553-4e2c-a070-5d60f2fec611
save_fig("Daily_distance.png", figure3)

# ╔═╡ 4a5c4d8a-1d5d-4458-885a-2658d9328489
md"
### Cumulative distance
---
"

# ╔═╡ 22081464-abb6-4157-98bc-80c361144105
figure4 = df_pedometer_filter |> 

@vlplot(:area, 
	x = {:create_time, "axis" = {"title" = "Time", "labelFontSize" = 12, "titleFontSize" = 14}, "type" = "temporal"}, 
	y = {:cumul_distance, "axis" = {"title" = "Aggregate daily distance [km]", "labelFontSize" = 12, "titleFontSize" = 14 }}, 
	width = 850, height = 500, 
	"title" = {"text" = "Cumulative distance from $(Date.(start_date)) to $(Date.(end_date))", "fontSize" = 16},
	)

# ╔═╡ fbb7c18f-82bb-4499-b608-687764ab391d
save_fig("Cumum_distance_2019_2021.png", figure4)

# ╔═╡ 0b0dc862-a8f4-4bc8-b5fd-50e74c221bc5
md"
### Distribution of active time
---

**Change the number of max bins by dragging the slider below**
"

# ╔═╡ cf320c13-2b65-4435-8f39-54d6217a7d1b
@bind bins2 Slider(25:75, default=50, show_value=true)

# ╔═╡ 61f017e1-ea63-4d6d-aedc-25d943871975
figure5 = df_pedometer_filter |> 

@vlplot(:bar, 
	x = {:active_time, "axis" = {"title" = "Measured active time [minutes]", "labelFontSize" = 12, "titleFontSize" = 14}, "bin" = {"maxbins" = bins2}}, 
	y = {"count()", "axis" = {"title" = "Number of counts", "labelFontSize" = 12, "titleFontSize" = 14 }}, 
	width = 850, height = 500, 
	"title" = {"text" = "Active time distribution from $(Date.(start_date)) to $(Date.(end_date))", "fontSize" = 16},
	color = :day_type)

# ╔═╡ f50e5792-4be7-4dc0-b5fb-ffc134320405
save_fig("Active_time_daytype_2019_2021.png", figure5)

# ╔═╡ 2389995c-1758-4d91-baf7-d3e0dcf7ce85
figure6 = df_pedometer_filter |> 

@vlplot(:bar, 
	x = {:active_time, "axis" = {"title" = "Measured active time [minutes]", "labelFontSize" = 12, "titleFontSize" = 14}, "bin" = {"maxbins" = bins2}}, 
	y = {"count()", "axis" = {"title" = "Number of counts", "labelFontSize" = 12, "titleFontSize" = 14 }}, 
	width = 850, height = 500, 
	"title" = {"text" = "Active time distribution from $(Date.(start_date)) to $(Date.(end_date))", "fontSize" = 16},
	color = :day)

# ╔═╡ 7b6fe3e6-01b2-43b9-80a1-6aa62d90b0ad
md" I appear to be quite active on Wednesdays, that is surprising!"

# ╔═╡ b383c509-4704-406f-92e7-c8bc04210204
save_fig("Active_time_perday_2019_2021.png", figure6)

# ╔═╡ 007192c1-a745-4ced-8af4-c320c8e44181
md"
### Correlation between number of steps and calories
---

As expected, number of steps and total calories consumed have a direct correlation. This 2D histogram scatterplot also shows markers with size proportional to the total number of counts. Fewer data points exist for higher step counts. I should try to be more active this year!

**Move slider to select a year**
"

# ╔═╡ 1bb2cde7-f951-4d33-af50-46bef9a183c1
@bind select_year Slider(2018:2021; default=2019, show_value=true)

# ╔═╡ 3d63542e-5a51-4368-85e5-2e0be17ae991
figure7 = df_pedometer |> 

@filter(_.year == select_year) |>

@vlplot(:circle, 
	x = {:step_count, "axis" = {"title" = "Number of steps", "labelFontSize" = 14, "titleFontSize" = 14}, "bin" = {"maxbins" = 30}}, 
	y = {:calorie, "axis" = {"title" = "Calories", "labelFontSize" = 14, "titleFontSize" = 14 }, "bin" = {"maxbins" = 30}}, 
	width = 850, height = 500, 
	"title" = {"text" = "2D histogram scatterplot calories vs step count for $(select_year)", "fontSize" = 16},
	size = "count()")

# ╔═╡ 75e007d4-8f37-463f-ba9e-03548a771125
save_fig("Step_count_vs_calories_$(select_year).png", figure7)

# ╔═╡ d8a77ace-18e6-4c3f-a56c-0a4bf65c536f
md"
### Heatmap of step count vs active time
---
"

# ╔═╡ 6e043d91-8b33-49e2-ab0c-e5c3cb86fd15
md" 
**Move slider to select a year:** $(@bind select_year_2 Slider(2018:2021; default=2019, show_value=true))
"

# ╔═╡ 7353321e-4849-4685-9276-57b8eefa0745
figure8 = df_pedometer |> 

@filter(_.year == select_year_2) |>

@vlplot(:rect,    
    x = {:step_count, "axis" = {"title" = "Number of steps", "labelFontSize" = 14, "titleFontSize" = 14}, "bin" = {"maxbins" = 30}}, 
    y = {:active_time, "axis" = {"title" = "Active time [mins]", "labelFontSize" = 14, "titleFontSize" = 14 }, "bin" = {"maxbins" = 30}}, 
    color = :distance,
    config={
        "range" = {
            heatmap={
                scheme="greenblue"
            }
        },
        "view" = {
            "stroke" = "transparent"
        }
    },
	width = 850, height = 500, 
	"title" = {"text" = " Heatmap of step count vs active time for $(select_year_2) seen on the distance [km] scale", "fontSize" = 16},
)

# ╔═╡ f02e1137-25cd-4d9c-bea8-4822beecd4e0
save_fig("Heatmap_$(select_year).png", figure8)

# ╔═╡ c24250e2-5d8f-464a-8c33-48d165242163
md"
## Visualizing heart rate data

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
### Scatter plot of heart rate data
---
"

# ╔═╡ f35989fa-903c-4d79-9cbc-59ab4ff9ff2f
figure9 = df_heart_filter |> 

@vlplot(:circle, 
	x = {:create_time, "axis" = {"title" = "Time", "labelFontSize" = 12, "titleFontSize" = 14}, "type" = "temporal"}, 
	y = {:heart_rate, "axis" = {"title" = "Measured heart rate [bpm]", "labelFontSize" = 12, "titleFontSize" = 14 }}, 
	width = 850, height = 500, 
	"title" = {"text" = "Heart rate from $(Date.(start_date)) to $(Date.(end_date))", "fontSize" = 16},
	size = :heart_rate)

# ╔═╡ fbdd8dca-6c08-445a-9965-76321eafd41f
save_fig("Heart_rate_2019_2021.png", figure9)

# ╔═╡ ce3f3eb8-a7d0-4b05-942a-ec4bf1df5a6f
md"
### Heart rate distribution
---

Heart rate is measured by my watch every 10 minutes. I wear it almost everyday. That means most of the data points are collected while I am sitting (mostly relaxed) at my desk for work. Data appears to be clustered around the resting heart rate range of 60-100 beats per minute (bpm) with a mean around 79 bpm. That's a relief!

**Move slider to select a year**
"

# ╔═╡ 4bf8b146-bf39-4e56-90dc-572003e49f0e
@bind select_year_1 Slider(2018:2021; default=2019, show_value=true)

# ╔═╡ d2789f5e-3642-4a39-9776-60959c553990
begin
	df_heart_year = df_heart |> @filter(_.create_time > DateTime(select_year_1) && _.create_time < DateTime(select_year_1 + 1)) |> DataFrame	
		
	μ = mean(df_heart_year[!,:heart_rate]) # calculate mean heart rate
	
	figure10 = df_heart_year |> @vlplot(:bar, 
		x = {:heart_rate, "axis" = {"title" = "Measured heart rate [bpm]", "labelFontSize" = 12, "titleFontSize" = 14}}, 
		y = {"count()", "axis" = {"title" = "Number of counts", "labelFontSize" = 12, "titleFontSize" = 14 }}, 
		width = 850, height = 500, 
		"title" = {"text" = "Heart rate distribution for $(select_year_1) with mean = $(round(μ, digits = 2)) bpm", "fontSize" = 16},
		color = :heart_rate)
end

# ╔═╡ 30e2f5e2-7ec6-4978-8f7e-eb3a344af155
save_fig("Heart_rate_distribution_2021.png", figure10)

# ╔═╡ d8ad02a1-c0e7-47d7-8814-3d4f994c953c
md"
## Visualizing climbed floors data

"

# ╔═╡ bd47dea3-3ad4-41d0-9104-81cf2bce8ad8
begin
	df_floors = deepcopy(df_floors_raw)
	df_floors[!, :create_time] = DateTime.(df_floors[!, :create_time], datef)
	sort!(df_floors, :create_time)	
end

# ╔═╡ ec0fd3dc-a7ae-4331-af9b-2a547441befa
md"
### Number of floors climbed
---

Nothing too exciting here, except for a huge spike in Nov, 2019. I was wearing this watch during a short hike in the city of Nainital, India. An elevation change of 9 feet is recorded as one floor climb. So, 65 floors indicates that I must have climbed 585 feet ~ 178 m during that time. Phew!
"

# ╔═╡ 7167ce6d-1b77-48e6-ad78-a8082b87b8eb
figure11 = df_floors |> 

@filter(_.create_time > start_date &&  _.create_time < end_date) |> 

@vlplot(:bar, 
	x = {:create_time, "axis" = {"title" = "Time", "labelFontSize" = 12, "titleFontSize" = 14}}, 
	y = {:floor, "axis" = {"title" = "Number of floors", "labelFontSize" = 12, "titleFontSize" = 14 }}, 
	width = 850, height = 500, 
	"title" = {"text" = "Floors climbed from $(Date.(start_date)) to $(Date.(end_date))", "fontSize" = 16})

# ╔═╡ b592de9e-2c80-49c8-8525-1cbddae6fb16
save_fig("Floors_2019_2021.png", figure11)

# ╔═╡ 5430d24e-53b6-4189-bf7d-328b514e5b1f
md"
## References

1. [Analyzing Samsung Health Step data](https://www.kaggle.com/simon0204/analyzing-samsung-health-step-data)
2. [extract-health-data-from-your-samsung](https://towardsdatascience.com/extract-health-data-from-your-samsung-96b8a2e31978)
3. [VegaLite.jl](https://www.queryverse.org/VegaLite.jl/stable/examples/examples_histograms/)
"

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
CSV = "336ed68f-0bac-5ca0-87d4-7b16caf5d00b"
DataFrames = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
Dates = "ade2ca70-3891-5945-98fb-dc099432e06a"
HTTP = "cd3eb016-35fb-5094-929b-558a96fad6f3"
PlutoUI = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
Query = "1a8c2f83-1ff3-5112-b086-8aa67b057ba1"
Statistics = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"
VegaLite = "112f6efa-9a02-5b7d-90c0-432ed331239a"

[compat]
CSV = "~0.9.5"
DataFrames = "~1.2.2"
HTTP = "~0.9.16"
PlutoUI = "~0.7.14"
Query = "~1.0.0"
VegaLite = "~2.6.0"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

[[ArgTools]]
uuid = "0dad84c5-d112-42e6-8d28-ef12dabb789f"

[[Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"

[[Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"

[[CSV]]
deps = ["CodecZlib", "Dates", "FilePathsBase", "InlineStrings", "Mmap", "Parsers", "PooledArrays", "SentinelArrays", "Tables", "Unicode", "WeakRefStrings"]
git-tree-sha1 = "15b18ea098a4b5af316df529c2ff4055fcef36e9"
uuid = "336ed68f-0bac-5ca0-87d4-7b16caf5d00b"
version = "0.9.5"

[[CodecZlib]]
deps = ["TranscodingStreams", "Zlib_jll"]
git-tree-sha1 = "ded953804d019afa9a3f98981d99b33e3db7b6da"
uuid = "944b1d66-785c-5afd-91f1-9de20f533193"
version = "0.7.0"

[[Compat]]
deps = ["Base64", "Dates", "DelimitedFiles", "Distributed", "InteractiveUtils", "LibGit2", "Libdl", "LinearAlgebra", "Markdown", "Mmap", "Pkg", "Printf", "REPL", "Random", "SHA", "Serialization", "SharedArrays", "Sockets", "SparseArrays", "Statistics", "Test", "UUIDs", "Unicode"]
git-tree-sha1 = "31d0151f5716b655421d9d75b7fa74cc4e744df2"
uuid = "34da2185-b29b-5c13-b0c7-acf172513d20"
version = "3.39.0"

[[ConstructionBase]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "f74e9d5388b8620b4cee35d4c5a618dd4dc547f4"
uuid = "187b0558-2788-49d3-abe0-74a17ed4e7c9"
version = "1.3.0"

[[Crayons]]
git-tree-sha1 = "3f71217b538d7aaee0b69ab47d9b7724ca8afa0d"
uuid = "a8cc5b0e-0ffa-5ad4-8c14-923d3ee1735f"
version = "4.0.4"

[[DataAPI]]
git-tree-sha1 = "cc70b17275652eb47bc9e5f81635981f13cea5c8"
uuid = "9a962f9c-6df0-11e9-0e5d-c546b8b5ee8a"
version = "1.9.0"

[[DataFrames]]
deps = ["Compat", "DataAPI", "Future", "InvertedIndices", "IteratorInterfaceExtensions", "LinearAlgebra", "Markdown", "Missings", "PooledArrays", "PrettyTables", "Printf", "REPL", "Reexport", "SortingAlgorithms", "Statistics", "TableTraits", "Tables", "Unicode"]
git-tree-sha1 = "d785f42445b63fc86caa08bb9a9351008be9b765"
uuid = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
version = "1.2.2"

[[DataStructures]]
deps = ["Compat", "InteractiveUtils", "OrderedCollections"]
git-tree-sha1 = "7d9d316f04214f7efdbb6398d545446e246eff02"
uuid = "864edb3b-99cc-5e75-8d2d-829cb0a9cfe8"
version = "0.18.10"

[[DataValueInterfaces]]
git-tree-sha1 = "bfc1187b79289637fa0ef6d4436ebdfe6905cbd6"
uuid = "e2d170a0-9d28-54be-80f0-106bbe20a464"
version = "1.0.0"

[[DataValues]]
deps = ["DataValueInterfaces", "Dates"]
git-tree-sha1 = "d88a19299eba280a6d062e135a43f00323ae70bf"
uuid = "e7dc6d0d-1eca-5fa6-8ad6-5aecde8b7ea5"
version = "0.4.13"

[[Dates]]
deps = ["Printf"]
uuid = "ade2ca70-3891-5945-98fb-dc099432e06a"

[[DelimitedFiles]]
deps = ["Mmap"]
uuid = "8bb1440f-4735-579b-a4ab-409b98df4dab"

[[Distributed]]
deps = ["Random", "Serialization", "Sockets"]
uuid = "8ba89e20-285c-5b6f-9357-94700520ee1b"

[[Downloads]]
deps = ["ArgTools", "LibCURL", "NetworkOptions"]
uuid = "f43a241f-c20a-4ad4-852c-f6b1247861c6"

[[FileIO]]
deps = ["Pkg", "Requires", "UUIDs"]
git-tree-sha1 = "3c041d2ac0a52a12a27af2782b34900d9c3ee68c"
uuid = "5789e2e9-d7fb-5bc7-8068-2c6fae9b9549"
version = "1.11.1"

[[FilePaths]]
deps = ["FilePathsBase", "MacroTools", "Reexport", "Requires"]
git-tree-sha1 = "919d9412dbf53a2e6fe74af62a73ceed0bce0629"
uuid = "8fc22ac5-c921-52a6-82fd-178b2807b824"
version = "0.8.3"

[[FilePathsBase]]
deps = ["Dates", "Mmap", "Printf", "Test", "UUIDs"]
git-tree-sha1 = "7fb0eaac190a7a68a56d2407a6beff1142daf844"
uuid = "48062228-2e41-5def-b9a4-89aafe57970f"
version = "0.9.12"

[[Formatting]]
deps = ["Printf"]
git-tree-sha1 = "8339d61043228fdd3eb658d86c926cb282ae72a8"
uuid = "59287772-0a20-5a39-b81b-1366585eb4c0"
version = "0.4.2"

[[Future]]
deps = ["Random"]
uuid = "9fa8497b-333b-5362-9e8d-4d0656e87820"

[[HTTP]]
deps = ["Base64", "Dates", "IniFile", "Logging", "MbedTLS", "NetworkOptions", "Sockets", "URIs"]
git-tree-sha1 = "14eece7a3308b4d8be910e265c724a6ba51a9798"
uuid = "cd3eb016-35fb-5094-929b-558a96fad6f3"
version = "0.9.16"

[[HypertextLiteral]]
git-tree-sha1 = "72053798e1be56026b81d4e2682dbe58922e5ec9"
uuid = "ac1192a8-f4b3-4bfe-ba22-af5b92cd3ab2"
version = "0.9.0"

[[IOCapture]]
deps = ["Logging", "Random"]
git-tree-sha1 = "f7be53659ab06ddc986428d3a9dcc95f6fa6705a"
uuid = "b5f81e59-6552-4d32-b1f0-c071b021bf89"
version = "0.2.2"

[[IniFile]]
deps = ["Test"]
git-tree-sha1 = "098e4d2c533924c921f9f9847274f2ad89e018b8"
uuid = "83e8ac13-25f8-5344-8a64-a9f2b223428f"
version = "0.5.0"

[[InlineStrings]]
deps = ["Parsers"]
git-tree-sha1 = "19cb49649f8c41de7fea32d089d37de917b553da"
uuid = "842dd82b-1e85-43dc-bf29-5d0ee9dffc48"
version = "1.0.1"

[[InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"

[[InvertedIndices]]
git-tree-sha1 = "bee5f1ef5bf65df56bdd2e40447590b272a5471f"
uuid = "41ab1584-1d38-5bbf-9106-f11c6c58b48f"
version = "1.1.0"

[[IterableTables]]
deps = ["DataValues", "IteratorInterfaceExtensions", "Requires", "TableTraits", "TableTraitsUtils"]
git-tree-sha1 = "70300b876b2cebde43ebc0df42bc8c94a144e1b4"
uuid = "1c8ee90f-4401-5389-894e-7a04a3dc0f4d"
version = "1.0.0"

[[IteratorInterfaceExtensions]]
git-tree-sha1 = "a3f24677c21f5bbe9d2a714f95dcd58337fb2856"
uuid = "82899510-4779-5014-852e-03e436cf321d"
version = "1.0.0"

[[JSON]]
deps = ["Dates", "Mmap", "Parsers", "Unicode"]
git-tree-sha1 = "8076680b162ada2a031f707ac7b4953e30667a37"
uuid = "682c06a0-de6a-54ab-a142-c8b1cf79cde6"
version = "0.21.2"

[[JSONSchema]]
deps = ["HTTP", "JSON", "URIs"]
git-tree-sha1 = "2f49f7f86762a0fbbeef84912265a1ae61c4ef80"
uuid = "7d188eb4-7ad8-530c-ae41-71a32a6d4692"
version = "0.3.4"

[[LibCURL]]
deps = ["LibCURL_jll", "MozillaCACerts_jll"]
uuid = "b27032c2-a3e7-50c8-80cd-2d36dbcbfd21"

[[LibCURL_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "MbedTLS_jll", "Zlib_jll", "nghttp2_jll"]
uuid = "deac9b47-8bc7-5906-a0fe-35ac56dc84c0"

[[LibGit2]]
deps = ["Base64", "NetworkOptions", "Printf", "SHA"]
uuid = "76f85450-5226-5b5a-8eaa-529ad045b433"

[[LibSSH2_jll]]
deps = ["Artifacts", "Libdl", "MbedTLS_jll"]
uuid = "29816b5a-b9ab-546f-933c-edad1886dfa8"

[[Libdl]]
uuid = "8f399da3-3557-5675-b5ff-fb832c97cbdb"

[[LinearAlgebra]]
deps = ["Libdl"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"

[[Logging]]
uuid = "56ddb016-857b-54e1-b83d-db4d58db5568"

[[MacroTools]]
deps = ["Markdown", "Random"]
git-tree-sha1 = "5a5bc6bf062f0f95e62d0fe0a2d99699fed82dd9"
uuid = "1914dd2f-81c6-5fcd-8719-6d5c9610ff09"
version = "0.5.8"

[[Markdown]]
deps = ["Base64"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"

[[MbedTLS]]
deps = ["Dates", "MbedTLS_jll", "Random", "Sockets"]
git-tree-sha1 = "1c38e51c3d08ef2278062ebceade0e46cefc96fe"
uuid = "739be429-bea8-5141-9913-cc70e7f3736d"
version = "1.0.3"

[[MbedTLS_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "c8ffd9c3-330d-5841-b78e-0817d7145fa1"

[[Missings]]
deps = ["DataAPI"]
git-tree-sha1 = "bf210ce90b6c9eed32d25dbcae1ebc565df2687f"
uuid = "e1d29d7a-bbdc-5cf2-9ac0-f12de2c33e28"
version = "1.0.2"

[[Mmap]]
uuid = "a63ad114-7e13-5084-954f-fe012c677804"

[[MozillaCACerts_jll]]
uuid = "14a3606d-f60d-562e-9121-12d972cd8159"

[[NetworkOptions]]
uuid = "ca575930-c2e3-43a9-ace4-1e988b2c1908"

[[NodeJS]]
deps = ["Pkg"]
git-tree-sha1 = "905224bbdd4b555c69bb964514cfa387616f0d3a"
uuid = "2bd173c7-0d6d-553b-b6af-13a54713934c"
version = "1.3.0"

[[OrderedCollections]]
git-tree-sha1 = "85f8e6578bf1f9ee0d11e7bb1b1456435479d47c"
uuid = "bac558e1-5e72-5ebc-8fee-abe8a469f55d"
version = "1.4.1"

[[Parsers]]
deps = ["Dates"]
git-tree-sha1 = "a8709b968a1ea6abc2dc1967cb1db6ac9a00dfb6"
uuid = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"
version = "2.0.5"

[[Pkg]]
deps = ["Artifacts", "Dates", "Downloads", "LibGit2", "Libdl", "Logging", "Markdown", "Printf", "REPL", "Random", "SHA", "Serialization", "TOML", "Tar", "UUIDs", "p7zip_jll"]
uuid = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"

[[PlutoUI]]
deps = ["Base64", "Dates", "HypertextLiteral", "IOCapture", "InteractiveUtils", "JSON", "Logging", "Markdown", "Random", "Reexport", "UUIDs"]
git-tree-sha1 = "d1fb76655a95bf6ea4348d7197b22e889a4375f4"
uuid = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
version = "0.7.14"

[[PooledArrays]]
deps = ["DataAPI", "Future"]
git-tree-sha1 = "a193d6ad9c45ada72c14b731a318bedd3c2f00cf"
uuid = "2dfb63ee-cc39-5dd5-95bd-886bf059d720"
version = "1.3.0"

[[PrettyTables]]
deps = ["Crayons", "Formatting", "Markdown", "Reexport", "Tables"]
git-tree-sha1 = "6330e0c350997f80ed18a9d8d9cb7c7ca4b3a880"
uuid = "08abe8d2-0d0c-5749-adfa-8a2ac140af0d"
version = "1.2.0"

[[Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"

[[Query]]
deps = ["DataValues", "IterableTables", "MacroTools", "QueryOperators", "Statistics"]
git-tree-sha1 = "a66aa7ca6f5c29f0e303ccef5c8bd55067df9bbe"
uuid = "1a8c2f83-1ff3-5112-b086-8aa67b057ba1"
version = "1.0.0"

[[QueryOperators]]
deps = ["DataStructures", "DataValues", "IteratorInterfaceExtensions", "TableShowUtils"]
git-tree-sha1 = "911c64c204e7ecabfd1872eb93c49b4e7c701f02"
uuid = "2aef5ad7-51ca-5a8f-8e88-e75cf067b44b"
version = "0.9.3"

[[REPL]]
deps = ["InteractiveUtils", "Markdown", "Sockets", "Unicode"]
uuid = "3fa0cd96-eef1-5676-8a61-b3b8758bbffb"

[[Random]]
deps = ["Serialization"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"

[[Reexport]]
git-tree-sha1 = "45e428421666073eab6f2da5c9d310d99bb12f9b"
uuid = "189a3867-3050-52da-a836-e630ba90ab69"
version = "1.2.2"

[[Requires]]
deps = ["UUIDs"]
git-tree-sha1 = "4036a3bd08ac7e968e27c203d45f5fff15020621"
uuid = "ae029012-a4dd-5104-9daa-d747884805df"
version = "1.1.3"

[[SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"

[[SentinelArrays]]
deps = ["Dates", "Random"]
git-tree-sha1 = "54f37736d8934a12a200edea2f9206b03bdf3159"
uuid = "91c51154-3ec4-41a3-a24f-3f23e20d615c"
version = "1.3.7"

[[Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"

[[Setfield]]
deps = ["ConstructionBase", "Future", "MacroTools", "Requires"]
git-tree-sha1 = "fca29e68c5062722b5b4435594c3d1ba557072a3"
uuid = "efcf1570-3423-57d1-acb7-fd33fddbac46"
version = "0.7.1"

[[SharedArrays]]
deps = ["Distributed", "Mmap", "Random", "Serialization"]
uuid = "1a1011a3-84de-559e-8e89-a11a2f7dc383"

[[Sockets]]
uuid = "6462fe0b-24de-5631-8697-dd941f90decc"

[[SortingAlgorithms]]
deps = ["DataStructures"]
git-tree-sha1 = "b3363d7460f7d098ca0912c69b082f75625d7508"
uuid = "a2af1166-a08f-5f64-846c-94a0d3cef48c"
version = "1.0.1"

[[SparseArrays]]
deps = ["LinearAlgebra", "Random"]
uuid = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"

[[Statistics]]
deps = ["LinearAlgebra", "SparseArrays"]
uuid = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"

[[TOML]]
deps = ["Dates"]
uuid = "fa267f1f-6049-4f14-aa54-33bafae1ed76"

[[TableShowUtils]]
deps = ["DataValues", "Dates", "JSON", "Markdown", "Test"]
git-tree-sha1 = "14c54e1e96431fb87f0d2f5983f090f1b9d06457"
uuid = "5e66a065-1f0a-5976-b372-e0b8c017ca10"
version = "0.2.5"

[[TableTraits]]
deps = ["IteratorInterfaceExtensions"]
git-tree-sha1 = "c06b2f539df1c6efa794486abfb6ed2022561a39"
uuid = "3783bdb8-4a98-5b6b-af9a-565f29a5fe9c"
version = "1.0.1"

[[TableTraitsUtils]]
deps = ["DataValues", "IteratorInterfaceExtensions", "Missings", "TableTraits"]
git-tree-sha1 = "78fecfe140d7abb480b53a44f3f85b6aa373c293"
uuid = "382cd787-c1b6-5bf2-a167-d5b971a19bda"
version = "1.0.2"

[[Tables]]
deps = ["DataAPI", "DataValueInterfaces", "IteratorInterfaceExtensions", "LinearAlgebra", "TableTraits", "Test"]
git-tree-sha1 = "1162ce4a6c4b7e31e0e6b14486a6986951c73be9"
uuid = "bd369af6-aec1-5ad0-b16a-f7cc5008161c"
version = "1.5.2"

[[Tar]]
deps = ["ArgTools", "SHA"]
uuid = "a4e569a6-e804-4fa4-b0f3-eef7a1d5b13e"

[[Test]]
deps = ["InteractiveUtils", "Logging", "Random", "Serialization"]
uuid = "8dfed614-e22c-5e08-85e1-65c5234f0b40"

[[TranscodingStreams]]
deps = ["Random", "Test"]
git-tree-sha1 = "216b95ea110b5972db65aa90f88d8d89dcb8851c"
uuid = "3bb67fe8-82b1-5028-8e26-92a6c54297fa"
version = "0.9.6"

[[URIParser]]
deps = ["Unicode"]
git-tree-sha1 = "53a9f49546b8d2dd2e688d216421d050c9a31d0d"
uuid = "30578b45-9adc-5946-b283-645ec420af67"
version = "0.4.1"

[[URIs]]
git-tree-sha1 = "97bbe755a53fe859669cd907f2d96aee8d2c1355"
uuid = "5c2747f8-b7ea-4ff2-ba2e-563bfd36b1d4"
version = "1.3.0"

[[UUIDs]]
deps = ["Random", "SHA"]
uuid = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"

[[Unicode]]
uuid = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"

[[Vega]]
deps = ["DataStructures", "DataValues", "Dates", "FileIO", "FilePaths", "IteratorInterfaceExtensions", "JSON", "JSONSchema", "MacroTools", "NodeJS", "Pkg", "REPL", "Random", "Setfield", "TableTraits", "TableTraitsUtils", "URIParser"]
git-tree-sha1 = "43f83d3119a868874d18da6bca0f4b5b6aae53f7"
uuid = "239c3e63-733f-47ad-beb7-a12fde22c578"
version = "2.3.0"

[[VegaLite]]
deps = ["Base64", "DataStructures", "DataValues", "Dates", "FileIO", "FilePaths", "IteratorInterfaceExtensions", "JSON", "MacroTools", "NodeJS", "Pkg", "REPL", "Random", "TableTraits", "TableTraitsUtils", "URIParser", "Vega"]
git-tree-sha1 = "3e23f28af36da21bfb4acef08b144f92ad205660"
uuid = "112f6efa-9a02-5b7d-90c0-432ed331239a"
version = "2.6.0"

[[WeakRefStrings]]
deps = ["DataAPI", "InlineStrings", "Parsers"]
git-tree-sha1 = "c69f9da3ff2f4f02e811c3323c22e5dfcb584cfa"
uuid = "ea10d353-3f73-51f8-a26c-33c1cb351aa5"
version = "1.4.1"

[[Zlib_jll]]
deps = ["Libdl"]
uuid = "83775a58-1f1d-513f-b197-d71354ab007a"

[[nghttp2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850ede-7688-5339-a07c-302acd2aaf8d"

[[p7zip_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "3f19e933-33d8-53b3-aaab-bd5110c3b7a0"
"""

# ╔═╡ Cell order:
# ╟─8268035c-aaf7-4811-b858-20161b57a0b9
# ╟─c5aa61e2-06b9-4bb6-819f-b0043d5bf932
# ╠═bb24143d-9a1c-41c9-9328-40e4186dc86b
# ╟─f656c150-eeb8-4eb7-8c8f-48f213d14a88
# ╟─68a82310-ea56-4c79-937d-fd3f12961617
# ╠═0189cd8a-f034-4c20-8571-14fb5da873e7
# ╟─2c49defa-0695-4974-8154-9f9688108a51
# ╠═ffacf8a1-0750-48bd-880b-6c42014a7351
# ╠═5c1645d7-f51e-4f53-86ff-05b2e60865db
# ╟─8a38cbad-5684-4a8e-91fc-b38f787cd5e1
# ╠═7bc8f218-01c5-4956-a156-82c6d5cb7d5b
# ╠═bd5ffe99-b7ce-4883-9198-73391a71e695
# ╠═cc438ad3-da8b-4da6-9ccd-8dc47a098545
# ╠═824b9f5f-2b7c-414c-9aea-5a6877732139
# ╟─e83af676-3745-49fe-aa9c-e66fc3e2ef28
# ╟─eb1dc392-eb58-4034-8784-0a8ef79c4ff0
# ╟─b7dd0336-2dad-4c0c-b934-eb9d235b658d
# ╟─6fa76290-bb8b-4b96-b54f-c68e1c699a4a
# ╟─7b11af41-9d7e-425d-9517-1914165967bd
# ╟─15e32715-bfc8-4228-b7f8-9abac314a610
# ╠═277c7460-788f-4b93-b1d2-b4d4e4d0a14d
# ╟─7f427cfc-e21b-413b-821f-6f0d86954f1c
# ╠═dc3696c2-479b-4aa9-9552-bd858f475c2b
# ╠═84fad772-b232-4e46-b219-be9fec0a979b
# ╠═0ce2c55e-af3b-4843-8abf-64876bdaff0b
# ╟─0e27122a-f517-458a-a3de-ad4f6a0cbc60
# ╠═a5ea4203-08eb-4afd-ab36-564482274ec3
# ╟─c552099a-9025-4297-8825-a4242559122d
# ╠═9339dde8-2b00-406c-9fc4-ba34c4d8579c
# ╠═d850b608-bfb2-4b02-89cb-f2af27417a28
# ╟─5dc6a5f9-4ddb-4d57-87b7-df3e23155c56
# ╟─03c531ee-7177-4cfd-811b-ab902212fcdd
# ╠═d7146451-a459-48ca-878f-c75b874ccd21
# ╠═00712037-2c82-4fd2-9777-e49d313e54fa
# ╠═beb86d06-2294-482d-9d00-a2c72986915a
# ╟─7998fa73-c5f8-4497-8b8f-8c43222773d9
# ╠═41194cce-6f90-4404-827b-a24d3546dff0
# ╟─fe15cdda-3128-4a7f-be92-58cad62c5007
# ╠═19a9837e-db8e-4ff4-9f75-1c6f5ad9fc74
# ╠═8f1981a4-f553-4e2c-a070-5d60f2fec611
# ╟─4a5c4d8a-1d5d-4458-885a-2658d9328489
# ╠═22081464-abb6-4157-98bc-80c361144105
# ╠═fbb7c18f-82bb-4499-b608-687764ab391d
# ╟─0b0dc862-a8f4-4bc8-b5fd-50e74c221bc5
# ╠═cf320c13-2b65-4435-8f39-54d6217a7d1b
# ╟─61f017e1-ea63-4d6d-aedc-25d943871975
# ╟─f50e5792-4be7-4dc0-b5fb-ffc134320405
# ╟─2389995c-1758-4d91-baf7-d3e0dcf7ce85
# ╟─7b6fe3e6-01b2-43b9-80a1-6aa62d90b0ad
# ╠═b383c509-4704-406f-92e7-c8bc04210204
# ╟─007192c1-a745-4ced-8af4-c320c8e44181
# ╟─1bb2cde7-f951-4d33-af50-46bef9a183c1
# ╠═3d63542e-5a51-4368-85e5-2e0be17ae991
# ╠═75e007d4-8f37-463f-ba9e-03548a771125
# ╟─d8a77ace-18e6-4c3f-a56c-0a4bf65c536f
# ╠═6e043d91-8b33-49e2-ab0c-e5c3cb86fd15
# ╠═7353321e-4849-4685-9276-57b8eefa0745
# ╠═f02e1137-25cd-4d9c-bea8-4822beecd4e0
# ╟─c24250e2-5d8f-464a-8c33-48d165242163
# ╠═54e3fa06-f672-404e-bcdd-c414846df0f9
# ╠═2180887e-ff4b-4a22-be86-00c6cd72a285
# ╟─612fb369-0149-4090-ac2f-37a4926a1293
# ╟─b7e5fe84-e455-4b71-aba6-1b5927eed45e
# ╠═f35989fa-903c-4d79-9cbc-59ab4ff9ff2f
# ╠═fbdd8dca-6c08-445a-9965-76321eafd41f
# ╟─ce3f3eb8-a7d0-4b05-942a-ec4bf1df5a6f
# ╟─4bf8b146-bf39-4e56-90dc-572003e49f0e
# ╠═d2789f5e-3642-4a39-9776-60959c553990
# ╠═30e2f5e2-7ec6-4978-8f7e-eb3a344af155
# ╟─d8ad02a1-c0e7-47d7-8814-3d4f994c953c
# ╠═bd47dea3-3ad4-41d0-9104-81cf2bce8ad8
# ╟─ec0fd3dc-a7ae-4331-af9b-2a547441befa
# ╠═7167ce6d-1b77-48e6-ad78-a8082b87b8eb
# ╠═b592de9e-2c80-49c8-8525-1cbddae6fb16
# ╟─5430d24e-53b6-4189-bf7d-328b514e5b1f
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
