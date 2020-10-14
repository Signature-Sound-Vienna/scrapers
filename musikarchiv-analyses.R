library("SPARQL")
library("ggplot2")
library("ggrepel")
library("tidyr")
library("magrittr")
library("forcats")
library("dplyr" )
library("lubridate")
library("jsonlite")
library("stringr")

endpoint <- "http://localhost:9999/blazegraph/namespace/prosit/sparql"



worksPerformedQ <- "
PREFIX ny: <http://localhost:9999/vocab/>
PREFIX dcterm: <http://purl.org/dc/terms/>
SELECT ?title where { 
   ?s  a ny:ProgrammeItem ;
       dcterm:title ?title
} 
"
worksPerformed <- SPARQL(endpoint, worksPerformedQ)$results %>%
                    pivot_longer(everything(),names_to="NA", values_to="title")
worksPerformed$title <- factor(worksPerformed$title)

worksPerformed %>%
  count(title)

worksPerformed$title <- factor(worksPerformed$title)

timesWorksPerformedQ <- "
PREFIX ny: <http://localhost:9999/vocab/>
PREFIX dcterm: <http://purl.org/dc/terms/>
SELECT ?title (count(?s) as ?c) where { 
   ?s  a ny:ProgrammeItem ;
       dcterm:title ?title
} group by ?title
having (?c > 20)
order by desc(?c) ?title
"
timesWorksPerformed <- SPARQL(endpoint, timesWorksPerformedQ)$results
timesWorksPerformed$title <- factor(timesWorksPerformed$title)

ggplot(timesWorksPerformed, aes(reorder(title, -c), c)) + geom_bar(stat = "identity") + 
  theme_bw() +
  scale_y_continuous(breaks=seq(0,150,10)) + 
  theme(axis.text.x = element_text(angle = 90, vjust = 0.5, hjust=1)) + 
  labs(x="Work", y="Times performed", title="Pieces from Musikverein Archive performed more than 10 times in 'Silvester' and 'Neujahrs' concerts")

workComposerYearQ<- "
PREFIX ny: <http://localhost:9999/vocab/>
PREFIX dcterm: <http://purl.org/dc/terms/>
select ?composer ?year (count(?composer) as ?c) where { 
  ?s a ny:ProgrammeItem ;
    dcterm:creator ?composer ;
    dcterm:isPartOf ?performance .
    ?performance dcterm:date ?date .
  BIND(SUBSTR(?date, STRLEN(?date)-4) as ?year) .
} GROUP BY ?composer ?year
"
workComposerYear <- SPARQL(endpoint, workComposerYearQ)$results
workComposerYear$composer<- factor(workComposerYear$composer)
workComposerYear$year <- as.numeric(workComposerYear$year)


ggplot(workComposerYear, aes(composer, year, size=c)) + geom_point(shape=21, fill="white", color="black") +
  theme_bw() +
  theme(axis.text.x = element_text(angle = 90, vjust = 0.5, hjust=1)) + 
  labs(x="Composer", y="Year", 
       title="Num. pieces performed by composer by year. n.b., conflates Silvester and Neujahr of the same year!",
       size="Num. pieces"
       )

conductorComposerQ<- "
PREFIX ny: <http://localhost:9999/vocab/>
PREFIX dcterm: <http://purl.org/dc/terms/>
select ?conductor ?composer (count(?composer) as ?c) where { 
  ?s a ny:ProgrammeItem ;
    dcterm:creator ?composer ;
    dcterm:isPartOf ?performance .
  ?performance ny:Dirigent ?conductor .
} GROUP BY ?conductor ?composer
"
conductorComposer <- SPARQL(endpoint, conductorComposerQ)$results
conductorComposer$conductor<- factor(conductorComposer$conductor)
conductorComposer$composer<- factor(conductorComposer$composer)


conductorPiecesQ <- "
PREFIX ny: <http://localhost:9999/vocab/>
PREFIX dcterm: <http://purl.org/dc/terms/>
select ?conductor (count(?s) as ?numPieces) where { 
  ?s a ny:ProgrammeItem ;
    dcterm:isPartOf ?performance .
  ?performance ny:Dirigent ?conductor .
} GROUP BY ?conductor 
"

conductorPieces <- SPARQL(endpoint, conductorPiecesQ)$results
conductorPieces$conductor<- factor(conductorPieces$conductor)

conductorComposer <- conductorComposer %>% inner_join(conductorPieces) %>% mutate(c_normalised = c / numPieces)

ggplot(conductorComposer, aes(composer, conductor, size=c_normalised)) + geom_point(shape=21, fill="white", color="black") +
  theme_bw() +
  theme(axis.text.x = element_text(angle = 90, vjust = 0.5, hjust=1)) + 
  labs(x="Composer", y="Conductor", 
       title="Works by composer as proportion of pieces conducted.\n n.b., conflates Silvester and Neujahr of the same year!",
       size="Proportion"
       )

ggplot(conductorComposer, aes(composer, conductor, size=c)) + geom_point(shape=21, fill="white", color="black") +
  theme_bw() +
  theme(axis.text.x = element_text(angle = 90, vjust = 0.5, hjust=1)) + 
  labs(x="Composer", y="Conductor", 
       title="Works by composer as number of pieces conducted.\n n.b., conflates Silvester and Neujahr of the same year!",
       size="Num. pieces"
       )



#====================SPOTIFY DATA================================#

endpoint <- "http://localhost:9999/blazegraph/namespace/spotify/sparql"

track_analyses_features_donauwalzerQ <- "
PREFIX ny: <http://localhost:9999/vocab/>
PREFIX mo: <http://purl.org/ontology/mo/>
PREFIX dcterm: <http://purl.org/dc/terms/>
SELECT ?album ?albName ?year ?track ?trackNum ?trackName ?analyses ?features where { 
  ?album foaf:name ?albName ;
    mo:track ?track .
  ?track foaf:name ?trackName ;
    mo:track_number ?trackNum ;
    ny:audio_analysis ?analyses ;
    ny:audio_features ?features .
    FILTER(REGEX(?trackName, '.*Donau.*')) . # An der schönen blauen ...
    FILTER(!(REGEX(?trackName, '.*weibchen.*'))) . # exclude Donauweibchen
    FILTER(!(REGEX(?trackName, '.*strande.*'))) .  # exclude Vom Donaustrande
    BIND(SUBSTR(?albName, STRLEN(?albName)-3) as ?year) . # year number is always last 4 diigts
    FILTER(ISNUMERIC(xsd:integer(?year))) . # but some (e.g. compilations) don't have year; exclude them
}
"
 
track_analyses_features_radetzkyQ<- "
PREFIX ny: <http://localhost:9999/vocab/>
PREFIX mo: <http://purl.org/ontology/mo/>
PREFIX dcterm: <http://purl.org/dc/terms/>
SELECT ?album ?albName ?year ?track ?trackNum ?trackName ?analyses ?features where { 
  ?album foaf:name ?albName ;
    mo:track ?track .
  ?track foaf:name ?trackName ;
    mo:track_number ?trackNum ;
    ny:audio_analysis ?analyses ;
    ny:audio_features ?features .
    FILTER(REGEX(?trackName, '.*Radetzky.*')) . 
    BIND(SUBSTR(?albName, STRLEN(?albName)-3) as ?year) . # year number is always last 4 diigts
    FILTER(ISNUMERIC(xsd:integer(?year))) . # but some (e.g. compilations) don't have year; exclude them
}
"

album_publisherQ <- "
PREFIX ny: <http://localhost:9999/vocab/>
PREFIX mo: <http://purl.org/ontology/mo/>
PREFIX dcterm: <http://purl.org/dc/terms/>
SELECT ?album ?albName ?year ?label WHERE {
  ?album foaf:name ?albName ;
    mo:publisher ?label .
    BIND(SUBSTR(?albName, STRLEN(?albName)-3) as ?year) . # year number is always last 4 diigts
    FILTER(ISNUMERIC(xsd:integer(?year))) . # but some (e.g. compilations) don't have year; exclude them
}
"

#_dw below: Donauwalzer
#_rm below: Radetzky Marsch

track_analyses_features_rm <- SPARQL(endpoint, track_analyses_features_radetzkyQ)$results
track_analyses_features_dw <- SPARQL(endpoint, track_analyses_features_donauwalzerQ)$results

track_analyses_features_dw$analyses <- track_analyses_features_dw$analyses %>% 
                                      str_replace_all('"', '\"') %>% 
                                      str_replace_all("'", '"')
track_analyses_features_dw$features <- track_analyses_features_dw$features %>% 
                                      str_replace_all('"', '\"') %>% 
                                      str_replace_all("'", '"')

track_analyses_features_rm$analyses <- track_analyses_features_rm$analyses %>% 
                                      str_replace_all('"', '\"') %>% 
                                      str_replace_all("'", '"')
track_analyses_features_rm$features <- track_analyses_features_rm$features %>% 
                                      str_replace_all('"', '\"') %>% 
                                      str_replace_all("'", '"')

unpacked_analyses_bars <- function(track) { 
    return(cbind(track$track, parse_json(track$analyses, simplifyVector = TRUE)$bars))
}


donauwalzers <- tibble()
for(i in 1:nrow(track_analyses_features_dw)) { 
  donauwalzers <- rbind(donauwalzers,cbind(track_analyses_features_dw[i, c("year")], parse_json(track_analyses_features_dw[i, "analyses"], simplifyVector = TRUE)$bars))
}
names(donauwalzers) <- c("year","Sec", "duration", "confidence")

donauwalzers$year_n <- as.numeric(as.character(donauwalzers$year))

ggplot(donauwalzers%>%filter(confidence > 0.3)) + geom_vline(aes(xintercept=Sec, color=confidence)) + 
  facet_wrap(~year_n, ncol=1, strip.position = "left") + 
  theme_bw() + 
  scale_x_continuous(breaks=seq(0,800,20)) +
  labs(ylab="Year", title="An der schönen blauen Donau - spotify bar positions") 


radetzkys <- tibble()
for(i in 1:nrow(track_analyses_features_rm)) { 
  radetzkys <- rbind(radetzkys,cbind(track_analyses_features_rm[i, c("year")], parse_json(track_analyses_features_rm[i, "analyses"], simplifyVector = TRUE)$bars))
}
names(radetzkys) <- c("year","Sec", "duration", "confidence")

radetzkys$year_n <- as.numeric(as.character(radetzkys$year))

ggplot(radetzkys%>%filter(confidence > 0.3)) + geom_vline(aes(xintercept=Sec, color=confidence)) + 
  facet_wrap(~year_n, ncol=1, strip.position = "left") + 
  theme_bw() + 
  scale_x_continuous(breaks=seq(0,800,20)) +
  labs(ylab="Year", title="Radetzky Marsch - spotify bar positions") 


album_publishers <- SPARQL(endpoint, album_publisherQ)$results

# following info taken from manual inspection of WPhil and Amazon websites
album_publishers <- album_publishers %>% 
                      add_row(year=2015, label="Sony Classical") %>%
                      add_row(year=2013, label="Sony Classical") %>% 
                      add_row(year=2012, label="Sony Classical") %>% 
                      add_row(year=2011, label="Decca Records") %>% 
                      add_row(year=2010, label="Decca Records") %>% 
                      add_row(year=2009, label="Decca Records") %>% 
                      add_row(year=2008, label="Decca Records") %>% 
                      # 2007 as Sony Classical on WPhil but also exists separately as Deutsche Grammophon (Universal Music) on Amazon!
                      add_row(year=2006, label="Sony Classical / Deutsche Grammophon (Universal Music)") %>% 
                      add_row(year=2003, label="Sony Classical / Deutsche Grammophon (Universal Music)") %>% 
                      add_row(year=2002, label="Philips (Universal Music)") %>% 
                      add_row(year=1998, label="RCA Red Seal (Sony Music)") %>% 
                      add_row(year=1997, label="EMI Classics") %>% 
                      add_row(year=1993, label="Philips (Universal Music)") %>% 
                      add_row(year=1992, label="Sony Classical") %>% 
                      add_row(year=1991, label="Deutsche Grammophon (Universal Music)") %>% 
                      add_row(year=1988, label="Deutsche Grammophon (Universal Music)") %>% 
                      add_row(year=1987, label="Deutsche Grammophon (Universal Music)") %>% 
                      add_row(year=1983, label="Deutsche Grammophon (Universal Music)") %>% 
                      add_row(year=1980, label="Deutsche Grammophon (Universal Music)") %>% 
                      # 1980 - 1983 compilation available from Universal Japan
                      add_row(year=1979, label="Decca (Universal Music))") %>% 
                      # 1978 - 1979 compilation avialable on Vinyl from Decca DMR
                      add_row(year=1972, label="Decca (Universal Music))") %>% 
                      # 1972 Vinyl only
                      add_row(year=1967, label="Teldec") %>% 
                      # 1969 Vinyl only
                      add_row(year=1964, label="Teldec") %>% 
                      # 1964 Vinyl only
                      # 1963 - 1979 compilation available from Deutsche Grammophon
                      add_row(year=1954, label="Telefunken") %>% 
                      # 1954 - vinyl - as "Klemens Krauss dirigiert sein letztes Neujahrskonzert"
                      # 1951-1954 (CD) compilation as "Clemens Krauss: The New Year Concerts 1951-54"
                      add_row(year=1941, label="TON 4 Records") 
                      # 1986 not available on Amazon 
                                  
                      

# graph which piece was performed in which year, ordered by frequency of overall performances of piece
endpoint <- "http://localhost:9999/blazegraph/namespace/prosit/sparql"
worksByYearQ <- "
PREFIX ny: <http://localhost:9999/vocab/>
PREFIX dcterm: <http://purl.org/dc/terms/>
SELECT ?title ?year ?date ?is_silvester where { 
   ?s  a ny:ProgrammeItem ;
       dcterm:title ?title ;
       dcterm:isPartOf ?performance .
   ?performance dcterm:date ?date .
  BIND(CONTAINS(?date, 'Dezember') as ?is_silvester) .
  BIND(SUBSTR(?date, STRLEN(?date)-4) as ?year) .
} 
order by ?title"

worksByYear <- SPARQL(endpoint, worksByYearQ)$results %>%
  mutate(year = ifelse(is_silvester, as.numeric(year)+1, as.numeric(year))) %>%
  select(title, year) %>%
# manually add Donauwalzer and Radetzky for recent years (not listed on Musikverein site)
  add_row(title="An der schönen blauen Donau. Walzer, op. 314", year=2013) %>%
  add_row(title="An der schönen blauen Donau. Walzer, op. 314", year=2014) %>%
  add_row(title="An der schönen blauen Donau. Walzer, op. 314", year=2015) %>%
  add_row(title="An der schönen blauen Donau. Walzer, op. 314", year=2016) %>%
  add_row(title="An der schönen blauen Donau. Walzer, op. 314", year=2017) %>%
  add_row(title="An der schönen blauen Donau. Walzer, op. 314", year=2018) %>%
  add_row(title="An der schönen blauen Donau. Walzer, op. 314", year=2019) %>%
  add_row(title="An der schönen blauen Donau. Walzer, op. 314", year=2020) %>%
  add_row(title="Radetzky-Marsch, op. 228", year=2013) %>%
  add_row(title="Radetzky-Marsch, op. 228", year=2014) %>%
  add_row(title="Radetzky-Marsch, op. 228", year=2015) %>%
  add_row(title="Radetzky-Marsch, op. 228", year=2016) %>%
  add_row(title="Radetzky-Marsch, op. 228", year=2017) %>%
  add_row(title="Radetzky-Marsch, op. 228", year=2018) %>%
  add_row(title="Radetzky-Marsch, op. 228", year=2019) %>%
  add_row(title="Radetzky-Marsch, op. 228", year=2020) 


worksTimesPerformed <- worksByYear %>% 
  count(title)

worksByYear_TimesPerformed <- inner_join(worksByYear, worksTimesPerformed) %>%
  mutate(label = paste0(title, "\n(n=", n, ")")) %>%
  mutate(label = fct_reorder(label, n)) %>% # order by num performance %>%
  filter(n >= 40) %>% # at least 40 performances!
  distinct() # throw out duplicates (where there is more than 1 concert per year)
 
ggplot(worksByYear_TimesPerformed, aes(year, label)) + 
  geom_point(shape="|", size=5, alpha=1) + 
  theme_bw() + scale_x_continuous(breaks = seq(0, 2020, 10), minor_breaks=seq(0, 2020, 1)) +
  xlab("Year") + ylab("Work\n(n = number of times performed in series)")


worksYearsPerformed <- worksByYear %>% 
  distinct() %>%
  count(title)

worksByYear_YearsPerformed <- inner_join(worksByYear, worksYearsPerformed) %>%
  mutate(label = paste0(title, "\n(performed in ", n, " years)")) %>%
  mutate(label = fct_reorder(label, n)) %>% # order by num performance %>%
  filter(n >= 17)  # at least 17 years!

ggplot(worksByYear_YearsPerformed, aes(year, label)) + 
  geom_point(shape="|", size=5, alpha=1) + 
  theme_bw() + scale_x_continuous(breaks = seq(0, 2020, 10), minor_breaks=seq(0, 2020, 1)) +
  xlab("Year") + ylab("Piece") + ggtitle("Most frequently performed pieces", subtitle="Vienna Philharmonic New Years' Concert series")
    
         