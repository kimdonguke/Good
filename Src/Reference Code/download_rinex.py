from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.alert import Alert

import sys
import time
import os
    
# 사용자 입력
start_date = sys.argv[1]
end_date = sys.argv[2]

#start_date = input("시작일을 입력하세요 (예: YYYY-MM-DD): ")
#end_date = input("종료일을 입력하세요 (예: YYYY-MM-DD): ")
station_codes = input("관측소 코드를 콤마로 구분하여 입력하세요 (예: YONS,SUWN,ALL): ").split(',')

os.chdir('./data/ngii')

download_dir = os.path.join(os.getcwd(), f"{start_date}")

# 폴더가 없다면 생성
if not os.path.exists(download_dir):
    os.makedirs(download_dir)
    
# 크롬 드라이버 설정
options = Options()
options.add_experimental_option("detach", True)  # 브라우저 종료 안 되게

prefs = {
    "download.default_directory": download_dir,
    "download.prompt_for_download": False,
    "directory_upgrade": True,
    "safebrowsing.enabled": True
}
options.add_experimental_option("prefs", prefs)

driver = webdriver.Chrome(options=options)
wait = WebDriverWait(driver, 20)

# 웹사이트 열기
url = "https://www.gnssdata.or.kr/download/getDownloadView.do"
driver.get(url)

# 날짜 입력
start_input = wait.until(EC.presence_of_element_located((By.ID, "std_date_input")))
start_input.clear()
start_input.send_keys(start_date)

end_input = driver.find_element(By.ID, "end_date_input")
end_input.clear()
end_input.send_keys(end_date)

# 관측소 목록 가져오기
all_stations = wait.until(EC.presence_of_all_elements_located((By.XPATH, '//ul[@id="left_select_box"]/li')))
station_list = [station.get_attribute('key') for station in all_stations]

# 사용자가 'ALL'을 입력한 경우
if 'ALL' in [code.strip().upper() for code in station_codes]:
    # "ALL"을 입력하면 모든 관측소 선택
    station_codes = station_list  # 모든 관측소 리스트로 변경

    # 5개씩 나눠서 관측소 선택
    for i in range(0, len(station_codes), 5):
        current_batch = station_codes[i:i+5]
        
        # 추가할 관측소 선택
        for code in current_batch:
            try:
                li_xpath = f'//ul[@id="left_select_box"]/li[@key="{code}"]'
                station_li = wait.until(EC.element_to_be_clickable((By.XPATH, li_xpath)))
                station_li.click()
                print(f"[성공] 관측소 {code} 선택 완료")
            except:
                print(f"[실패] 관측소 {code} 를 찾을 수 없습니다.")
        
        # 선택된 관측소로 버튼 클릭 (add_allow_btn 사용)
        select_selected_btn = wait.until(EC.element_to_be_clickable((By.ID, "add_allow_btn")))
        select_selected_btn.click()

        # 다운로드 요청 버튼 클릭 (down_rinex_btn 사용)
        download_btn = wait.until(EC.element_to_be_clickable((By.ID, "down_rinex_btn")))
        download_btn.click()
        
        # 설문 조사 처리
        wait.until(EC.element_to_be_clickable((By.XPATH, "//label[contains(text(),'측량 및 지도제작')]/preceding-sibling::input"))).click()
        driver.find_element(By.XPATH, "//label[contains(text(),'홈페이지 안내')]/preceding-sibling::input").click()
        driver.find_element(By.XPATH, "//label[contains(text(),'만족')]/preceding-sibling::input").click()
        check_btn = wait.until(EC.element_to_be_clickable((By.ID, "btn_poll_add")))
        check_btn.click()

        # 첫 번째 팝업 확인
        try:
            alert = Alert(driver)
            alert_text = alert.text
            #print(f"[경고] 첫 번째 팝업 메시지: {alert_text}")
            alert.accept()
            time.sleep(1)

            # 추가 팝업 확인 (예: 데이터가 존재하지 않습니다)
            try:
                alert = Alert(driver)
                alert_text = alert.text
                #print(f"[경고] 두 번째 팝업 메시지: {alert_text}")
                alert.accept()
                time.sleep(1)
            except:
                pass  # 두 번째 팝업이 없으면 무시
        except:
            #print("[알림] 팝업이 나타나지 않았습니다.")
            pass

        # 다운로드 여유 시간
        time.sleep(5)
        print("[완료] 다운로드 요청이 완료되었습니다.")

        # 다운로드 여유 시간
        time.sleep(5)
        print(f"[완료] 다운로드 요청이 {i//5 + 1}번째 배치로 완료되었습니다.")
        
        # 제거할 관측소 선택
        for code in current_batch:
            try:
                li_xpath = f'//ul[@id="right_select_box"]/li[@key="{code}"]'
                station_li = wait.until(EC.element_to_be_clickable((By.XPATH, li_xpath)))
                station_li.click()
                print(f"[성공] 관측소 {code} 제거 완료")
            except:
                print(f"[실패] 관측소 {code} 를 찾을 수 없습니다.")
                
        # 선택된 관측소에서 지우기 (del_allow_btn 사용)
        delete_selected_btn = wait.until(EC.element_to_be_clickable((By.ID, "del_allow_btn")))
        delete_selected_btn.click()

else:
    # "ALL"이 아닌 경우, 사용자 입력 관측소만 선택
    for code in station_codes:
        code = code.strip().upper()
        if code in station_list:
            try:
                li_xpath = f'//ul[@id="left_select_box"]/li[@key="{code}"]'
                station_li = wait.until(EC.element_to_be_clickable((By.XPATH, li_xpath)))
                station_li.click()
                print(f"[성공] 관측소 {code} 선택 완료")
            except:
                print(f"[실패] 관측소 {code} 를 찾을 수 없습니다.")
        else:
            print(f"[실패] 관측소 {code} 가 목록에 없습니다.")

    # 선택된 관측소로 버튼 클릭 (add_allow_btn 사용)
    select_selected_btn = wait.until(EC.element_to_be_clickable((By.ID, "add_allow_btn")))
    select_selected_btn.click()

    # 다운로드 요청 버튼 클릭 (down_rinex_btn 사용)
    download_btn = wait.until(EC.element_to_be_clickable((By.ID, "down_rinex_btn")))
    download_btn.click()

    # 설문 조사 처리
    wait.until(EC.element_to_be_clickable((By.XPATH, "//label[contains(text(),'측량 및 지도제작')]/preceding-sibling::input"))).click()
    driver.find_element(By.XPATH, "//label[contains(text(),'홈페이지 안내')]/preceding-sibling::input").click()
    driver.find_element(By.XPATH, "//label[contains(text(),'만족')]/preceding-sibling::input").click()
    check_btn = wait.until(EC.element_to_be_clickable((By.ID, "btn_poll_add")))
    check_btn.click()
    
    # 팝업창의 확인 버튼 클릭
    confirm_popup_btn = Alert(driver)
    confirm_popup_btn.accept()

    # 다운로드 여유 시간
    time.sleep(10)
    print("[완료] 다운로드 요청이 완료되었습니다.")

print("모든 다운로드 요청이 완료되었습니다.")


