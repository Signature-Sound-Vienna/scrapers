import spotipy
from rdflib import RDF, FOAF, Namespace, Graph, URIRef, Literal, BNode
from pprint import pprint
from spotipy.oauth2 import SpotifyClientCredentials
from uuid import uuid4

baseUri = "http://localhost:9999"

g = Graph()
mo = Namespace("http://purl.org/ontology/mo/")
wde = Namespace("http://www.wikidata.org/entity/")
ny = Namespace(baseUri + "/vocab/")

def graphify(wpItems):
    g.add((wde.Q154685, FOAF.name, Literal("Wiener Philharmoniker") ))
    for idx, item in enumerate(wpItems):
        print(idx, item["name"], [artist["name"] for artist in item["artists"]], item["uri"])
        # mint a new Performance
        performance = str(uuid4())
        g.add((URIRef(performance), RDF.type, mo.Performance))
        # This was performed by the Wiener Philharmoniker
        g.add((wde.Q154685, mo.performed, URIRef(performance) ))
        # This was conducted by an artist
        for conductor in item["artists"]: 
            if conductor["name"] != "Wiener Philharmoniker":
                # assume artists that aren't the Phil are the conductor
                g.add(( URIRef(conductor["href"]), mo.conducted, URIRef(performance) )) 
                g.add(( URIRef(conductor["href"]), FOAF.name, Literal(conductor["name"]) ))
        # the performance produced a signal published as a Record (album)
        signal = performance + "#signal"
        g.add(( URIRef(performance), mo.recorded_as, URIRef(signal) ))
        g.add(( URIRef(signal), mo.published_as, URIRef(item["href"]) ))
        g.add(( URIRef(signal), RDF.type, mo.Signal ))
        g.add(( URIRef(item["href"]), RDF.type, mo.Record ))
        g.add(( URIRef(item["href"]), mo.publisher, Literal(item["label"]) ))
        g.add(( URIRef(item["href"]), FOAF.name, Literal(item["name"]) ))
        tracks = sp.album_tracks(item["uri"])
        for track in tracks["items"]:
            # the Record has tracks
            g.add(( URIRef(track["href"]), RDF.type, mo.Track ))
            g.add(( URIRef(track["href"]), FOAF.name, Literal(track["name"]) ))
            g.add(( URIRef(track["href"]), mo.track_number, Literal(track["track_number"]) ))
            g.add(( URIRef(item["href"]), mo.track, URIRef(track["href"]) ))
            g.add(( URIRef(track["href"]), ny.audio_analysis, Literal(sp.audio_analysis(track["uri"])) ))
            g.add(( URIRef(track["href"]), ny.audio_features, Literal(sp.audio_features([track["uri"]])) ))
    return g
#
def filterPhilharmoniker(items):
    # weed out "Neujahrskonzerte" not performed by the Wiener Philharmoniker
    for item in items:
         for artist in item["artists"]:
            if artist["name"] == "Wiener Philharmoniker":
                yield item

sp = spotipy.Spotify(auth_manager=SpotifyClientCredentials())

results = sp.search(q='album:Neujahrskonzert', type='album', limit=50)
    # n.b. as of 20200706, 'New Year' only adds a multi-year compilation, and 'Silvester' adds nothing significant
simplified = results['albums']['items'] # items here are 'simplified album objects', see Spotify Web API docs.
fullAlbumIds= [album["id"] for album in simplified]
fullAlbumObjects = [sp.album(fullAlbumId) for fullAlbumId in fullAlbumIds]
g = graphify(filterPhilharmoniker(fullAlbumObjects))
g.serialize(destination="output.ttl", format="turtle")
