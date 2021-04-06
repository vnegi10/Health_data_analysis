## Health_data_analysis

In this Pluto notebook, we will analyze my activity data obtained via the Samsung Health app. 
The data is recorded by sensors present in the: 1) Galaxy S9+ phone - steps, distance (via a pedometer) and 
(2) Gear S3 Frontier watch - steps, distance, climbed floors, and heart rate (via a photoplethysmogram). 
Data are available in the form of .csv files, which makes them quite easy to use.

## How to use?

Install Pluto.jl (if not done already) by executing the following commands in your Julia REPL:

    using Pkg
    Pkg.add("Pluto")
    using Pluto
    Pluto.run() 

Clone this repository and open Health_notebook.jl in your Pluto browser window. That's it! You are good to go.
