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
for st in searchterms:
    driver.get("https://www.wienerphilharmoniker.at/konzerte/archive/")
    elem = driver.find_element_by_id("dnn_ctr1820_View_stp_SearchTabbedPanel_ctl00_txt_SearchTerm")
    elem.clear()
    elem.send_keys(st)
    elem.send_keys(Keys.RETURN)
    element = WebDriverWait(driver, 30).until(
        EC.presence_of_element_located((By.ID, "eventListEntryContainer"))
    )
    content = driver.page_source
    soup = BeautifulSoup(content, features="lxml")
    currentPage = soup.select_one("#dnn_ctr1820_View_hf_CurrentPage").attrs["value"]
    maxPage = soup.select_one("#dnn_ctr1820_View_hf_MaxPage").attrs["value"]
    while True:
        # scrape performances on page
        for perf in soup.select('#eventListEntryContainer a'):
            performances.add(perf['href'])
        if int(currentPage) < int(maxPage)-1:
            # politely go to next page
            time.sleep(1)
            driver.find_element_by_id("dnn_ctr1820_View_hl_PageTopForward").click()
            time.sleep(5) # hack - should wait for DOM update instead, but below doesnt work
#            WebDriverWait(driver, 30).until(
#                EC.text_to_be_present_in_element_value(
#                    "#dnn_ctr1820_View_hf_CurrentPage", str(int(currentPage)+1)
#                )
#            )
            content = driver.page_source
            soup = BeautifulSoup(content, features="lxml")
            currentPage = soup.select_one("#dnn_ctr1820_View_hf_CurrentPage").attrs["value"]
            print(currentPage, maxPage)
        else: 
            # all pages scraped
            break
perfList = [perf.replace("from-search/True", "") for perf in list(performances)]
with open("performances.txt", "w") as perfFile:
    perfFile.write("\n".join(perfList))