# result_fig — figure 모음 (작업 단위별)

모든 결과 figure는 이 폴더의 **작업 단위별 하위 폴더**에 저장한다.
각 스크립트가 자동으로 해당 폴더에 저장하도록 경로가 지정되어 있으므로,
새 figure를 추가할 때도 아래 분류를 따를 것 (새 작업 단위면 `NN_이름` 폴더 추가).

| 폴더 | 내용 | 생성 스크립트 | 관련 브랜치 |
|---|---|---|---|
| `01_망설계/` | 그리디·ILP 표준 지도, 면적 비교, 통계 4패널·커버리지 지도 | `run_pipeline.m`, `plots/run_stats.m` | main |
| `02_망검증_IDOP-MSD/` | 검증 1단계 기하 + 2단계 IDOP·MSD(legacy) CDF·heat·초과 지도 | `run_validation.m` | net-validation |
| `03_망검증_LSC/` | 검증 v2 LSC 모델 — 시나리오 만족율·CDF·heat·초과 지도 + 기선 70 km 비교(`_b70*`, 새 97국 데이터셋) | `run_validation_lsc.m` (+b70 은 일회성 스크립트) | lsc-validation, main |
| `04_외부상설감시국/` | 기관별 CORS 오버레이, 통합 감시 커버리지 | `plots/run_plot_cors.m`, `plots/run_plot_integrated.m` | cors-overlay |
| `05_기선상한스윕_70-100km/` | maxBaseKm 70/80/90/100 비교용 사본 (`_70`~`_100` 접미사) | 각 설정으로 파이프라인 재실행 후 수동 수집 | base70(70), main(100) |
| `01_망설계/구버전/` | 과거 실험 렌더 (구 70 km 데이터에 하드코딩 제목 등 — 참고용, 사용 금지) | — | — |

- PPT용 단계별 figure는 별도 폴더 `../figure_for_ppt/` 유지.
- 규격: 960×720(4:3), `print -r200`, legend 지도내 northeast (heat map 만 colorbar 예외).
- **지도류 figure는 한 figure에 지도 1개** (좌우 병합 분할 금지, 2026-07-24 확정). 망 간 비교는
  동일 clim 을 공유하는 개별 파일(`_old`/`_new` 등 접미사)로 산출한다.
- 스윕(05) 사본 주의: 각 브랜치의 canonical figure 는 해당 브랜치의 01~04 폴더가 원본이고,
  05 는 기선 상한 결정용 비교 사본이다 (`stats_panels_100` 등은 2026-07-21 재렌더본).
