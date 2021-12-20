from selenium import webdriver
from selenium.webdriver.common.keys import Keys
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from bs4 import BeautifulSoup
import time

searchterms = ["Neujahrskonzert", "Silvesterkonzert"]

driver = webdriver.Chrome("/usr/bin/chromedriver")
performances = set()

driver.get("https://www.wienerphilharmoniker.at/de/konzert-archiv")
# accept cookies to get rid of modal mask
driver.find_element_by_class_name("accept-cookie-settings").click()
# click on the "start date" year, set to 1939
driver.find_element_by_id("startYear").click()
driver.find_element_by_id("startDate.year").send_keys("1939", Keys.RETURN)
time.sleep(1)
# click on the "end date" year, set to last value
driver.find_element_by_id("endYear").click()
driver.find_element_by_id("endDate.year").send_keys(time.localtime().tm_year, Keys.RETURN)
time.sleep(1)
for st in searchterms:
    # open the filter menu
    driver.find_element_by_class_name("filter-button").click()
    # fold out the concert title menu
    driver.find_element_by_class_name("konzerttitel").click()
    # select any previous input to overwrite it
    driver.find_element_by_id("konzerttitel").send_keys(Keys.CONTROL, "a")
    # enter the search term
    driver.find_element_by_id("konzerttitel").send_keys(st, Keys.RETURN)
    time.sleep(1)
    # return from filter menu
    driver.find_element_by_class_name("return-filter").click()
    element = WebDriverWait(driver, 30).until(
        EC.presence_of_element_located((By.ID, "content"))
    )
    perf_anchors = driver.find_elements_by_css_selector(".event-module.selected h2 a")
    perfs = [perf.get_attribute("href") for perf in perf_anchors]
    performances.update(perfs)

print("Number of performances found: ", len(performances))

with open("performances.txt", "w") as perfFile:
    perfFile.write("\n".join(list(performances)))
