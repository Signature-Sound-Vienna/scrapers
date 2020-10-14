This repository includes a collection of Web and API scrapers that extract information pertaining to historical performances of the New Year's Concert by the Vienna Philharmonic Orchestra from the [Web archive of the Musikverein](https://www.musikverein.at/archiv), the venue of the concert series; and, information pertaining to commercial recordings of concerts in the series, from [Spotify's Web API](https://developer.spotify.com/documentation/web-api/). 

The scrapers produce output as Linked Data in RDF (Turtle) format. The R script that is also included in this repository reads this data from a triplestore, conducts some simple exploratory analyses, and generates visualisations such as these:

![](images/compositions_year.png?raw=true)

![](images/composer_year.png?raw=true)

![](images/Radetzky-spotify.png?raw=true)
