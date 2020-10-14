import argparse
import requests
import time 
from uuid import uuid4
from pprint import pprint
from bs4 import BeautifulSoup
from rdflib import RDF, FOAF, Namespace, Graph, URIRef, Literal, BNode
import urllib
from urllib import parse

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
            perfUri = URIRef(line.strip().rstrip("/"))
            g.add(( perfUri, RDF.type, mo.Performance ))
            datetimeloc_h4 = soup.select(".event_properties h4")
            g.add(( perfUri, dct.date, Literal(datetimeloc_h4[0].text.strip()) ))
            g.add(( perfUri, ny.timeOfDay, Literal(datetimeloc_h4[1].text.strip()) ))
            datetimeloc_p = soup.select_one(".event_properties p").text.strip().split("\r\n")
            g.add(( perfUri, ny.location, Literal(datetimeloc_p[0].strip()) ))
            g.add(( perfUri, ny.venue, Literal(datetimeloc_p[2].strip()) ))
            g.add(( perfUri, dct.title, Literal(soup.select_one(".DIV_MODULECONTAINER_threequarter h1").text.strip() )))

            agent_roles = soup.select(".DIV_MODULECONTAINER_threequarter p")
            for agent_role in agent_roles:
                job = agent_role.select_one("job")
                if job:
                    g.add(( perfUri, URIRef(baseUri + "/vocab/" + urllib.parse.quote(job.text.strip())), Literal(agent_role.select_one("name").text.strip()) ))

            programmeItems = soup.select("#dnn_ctr800_View_divProgramPane .DIV_MODULECONTAINER_half p:not(.P_pause)")
            itemNum = 1
            for item in programmeItems:
                programmeItemUri = URIRef(baseUri + "/programmeItems/" + str(uuid4()))
                g.add(( programmeItemUri, RDF.type, ny.ProgrammeItem ))
                g.add(( programmeItemUri, dct.isPartOf, perfUri))
                g.add(( programmeItemUri, dct.creator, Literal(item.select_one("name").text.strip()) ))
                item.select_one("name").decompose() # throw out composer name (decompose, ha ha)
                remainder = item.text.replace("\n", "").split("\r")
                titles = [title for title in remainder if title]
                for title in titles:
                    g.add(( programmeItemUri, dct.title, Literal(title) ))
                    g.add(( programmeItemUri, ny.programmeItemNumber, Literal(itemNum) ))
                    itemNum += 1 
        except:
            print("Failed to parse: ", line.strip())
        time.sleep(3)
g.serialize(destination=args.outfile, format="turtle")