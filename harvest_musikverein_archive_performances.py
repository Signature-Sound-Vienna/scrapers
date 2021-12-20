import argparse
import requests
import time 
import sys
from uuid import uuid4
from pprint import pprint
from bs4 import BeautifulSoup
from rdflib import RDF, FOAF, Namespace, Graph, URIRef, Literal, BNode
import urllib
from urllib import parse
from urllib.parse import parse_qs, quote

baseUri = "http://localhost:9999"

parser = argparse.ArgumentParser(description="Scrape Musikverein Archive performance URIs specified in an input file")
parser.add_argument('perffile', metavar='performance_uris', help='A file with a list of performance URIs, one per line')
parser.add_argument('outfile', metavar='outfile', help='Desired name for the output file (RDF as turtle)')
args = parser.parse_args()

mo = Namespace("http://purl.org/ontology/mo/")
dct = Namespace("http://purl.org/dc/terms/")
ny = Namespace(baseUri + "/vocab/")

g = Graph()
with open (args.perffile) as pf:
    for line in pf:
        if line.strip() == "":
            continue # skip blank lines
        while True:
            try:
                print("Getting: ", line.strip())
                r = requests.get(line.strip())
                soup = BeautifulSoup(r.content, features="lxml")
                break
            except:
                print("Fetch failed, retrying: ", line.strip())
                time.sleep(1)
        # fetch succeeded, attempt to parse
        try: 
            perfUri = URIRef(line.strip())
            perfId = line.strip().rstrip("/").rsplit("/",1)[1]
            g.add(( perfUri, RDF.type, mo.Performance ))
            googleCalendarLink = soup.select(".calendar+.menu-wrapper a")[1]["href"]
            # extract a date-ish string like 20110101T000000 from the Google Calendar link
            d = parse_qs(googleCalendarLink)["dates"][0].split("/")[0]
            # reform into ISO 8601 (yyyy-mm-dd)
            date = "-".join([d[0:4], d[4:6], d[6:8]])
            g.add(( perfUri, dct.date, Literal(date) ))
            # extract venue string
            venue = soup.select_one(".location").text
            g.add(( perfUri, ny.venue, Literal(venue) ))
            # extract title of event
            title = soup.select_one("h1").text
            g.add(( perfUri, dct.title, Literal(title) ))

            # work through agent roles
            agent_roles_div = soup.select_one(".programm-info div:nth-child(1)") 
            agent_roles = agent_roles_div.select(".entry .subhead")
            for role in agent_roles:
                job = role.text
                # find all the agents who do this job
                # (by iterating through sublines until we run out of them)
                sibling = role.find_next_sibling()
                while sibling:
                    if 'subline' in sibling.attrs['class']:
                        g.add(( perfUri, URIRef(baseUri + "/vocab/" + quote(job)), Literal(sibling.text) ))
                        sibling = sibling.find_next_sibling()
                    else:
                        break

            # get programme items
            programme = soup.select_one(".programm-info div:nth-child(2) .entry .subhead")
            if programme.text != "Programm":
                print("WARNING: UNEXPECTED PROGRAM CONTENT:", programme.text, perfUri)
            # work through programme items
            # expectation is that we always have one composer and one work title
            # do some rudimentary validation to check this
            sibling = programme.find_next_sibling()
            last_seen = "" 
            itemNum = 1
            while(sibling):
                if 'subline' in sibling.attrs['class'] and 'pause' in sibling.attrs['class']:
                    # intermission, ignore
                    pass
                elif 'subline' in sibling.attrs['class'] and 'cast-programm' in sibling.attrs['class']:
                    if last_seen == "work":
                        print("WARNING: Multiple works in a row. Something fishy?", perfUri, sibling.text)

                    if creator:
                        # found a work
                        programmeItemUri = URIRef(baseUri + "/programmeItems/" + perfId + "/" + str(itemNum))
                        g.add(( programmeItemUri, RDF.type, URIRef(ny.ProgrammeItem) ))
                        g.add(( programmeItemUri, dct.isPartOf, URIRef(perfUri) ))
                        g.add(( programmeItemUri, dct.title, Literal(sibling.text) ))
                        g.add(( programmeItemUri, dct.creator, Literal(creator) ))
                        g.add(( programmeItemUri, ny.programmeItemNumber, Literal(itemNum) ))
                        itemNum += 1
                    else:
                        print("WARNING: WORK WITHOUT CREATOR", perfUri, sibling.text)
                    last_seen = "work"
                elif 'subline' in sibling.attrs['class']:
                    if last_seen == "composer":
                        print("WARNING: Multiple composers in a row. Something fishy?", perfUri, sibling.text)
                    creator = sibling.text
                    last_seen = "composer"
                else:
                    print("WARNING: unexpected sibling in programme items", perfUri, sibling.attrs["class"])
                sibling = sibling.find_next_sibling()
        except Exception:
            print("Failed to parse: ", line.strip())
            print(sys.exc_info())
        time.sleep(1)
g.serialize(destination=args.outfile, format="turtle")
