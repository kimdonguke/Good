# plots — 망 최적화 시각화/리포트 코드

상위 폴더(`망최적화/`)의 **결과 파일(result_greedy.mat / result_ilp.mat)** 을 로드해서 그림·통계를 만든다.
→ 먼저 `run_pipeline.m`(통합, 둘 다) 또는 `run_greedy_area_max.m` / `run_ilp_area_max.m`(상위 폴더)을 실행해 결과를 저장할 것.

예외: `plot_net_map.m` 은 결과 파일이 아니라 (lon, lat, isRef)를 직접 받는 **드라이버 공용 지도 함수**
(표준 규격 960×720, legend northeast, colorbar 없음) — 세 드라이버가 모두 이걸 호출한다.

| 스크립트 | 출력 |
|---|---|
| `run_stats.m` | 초기/그리디/ILP 3열 통계표 + 4패널 플롯 + `stats_result.csv`(상위 폴더) |
| `run_plot_integrated.m` | 통합 감시 커버리지 지도 (우리 감시국 빨강 ∪ 타기관 CORS 초록) |
| `run_plot_cors.m` | 최적화 망 + 외부 상설 감시국(7개 기관, 마커·색 구분) 오버레이 지도 — `Data/CORS_coordinate_최종본.xlsx` 고시 XYZ→LLH 변환 |
| `ppt_step_figures.m` | 그리디 flowchart 단계별 PPT figure (input 1~7, 0=전체) → `../figure_for_ppt/*.png` |

헬퍼(플롯 전용): `load_cors_external.m`(상설 감시국 고시 ECEF→GRS80 LLH 로더 — 손상 XYZ 인
GAGE·HGDO 는 xlsx 참고열로 대체, `국토지리정보원` 소속 포함 총 225국 반환),
`net_stats.m`(망 통계 계산), `cors_stations.m`(구 하드코딩 38국 — legacy, run_plot_integrated 만 사용)

- 어떤 결과를 그릴지: 각 스크립트 상단의 `resultFile`을 `result_ilp.mat` ↔ `result_greedy.mat` 로 변경
- 알고리즘/파이프라인 코드(그리디·ILP·저장·배정표)는 상위 폴더에 있음
