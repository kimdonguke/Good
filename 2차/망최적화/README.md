# 망최적화 — 기준국→감시국 전환, 감시가능망 면적 최대화

위성기준점 99개소에서 일부를 감시국으로 전환할 때, "감시국을 포함하는 Delaunay 셀(유효셀)"의
합집합 면적을 최대화한다. 실무 주력 = **ILP**(빈-외접원 정식화, 전역최적 증명), 그리디 = 비교 기준.

## 실행 진입점 (드라이버)

| 스크립트 | 역할 |
|---|---|
| `run_pipeline.m` | **통합 파이프라인**: 데이터 → 그리디 → ILP → 비교/인증 → 실무 내보내기 → 지도 2장 + 막대 |
| `run_ilp_area_max.m` | ILP 단독 + LP 상한 인증 + 실무 내보내기 (`result_ilp.mat` 생성) |
| `run_greedy_area_max.m` | 그리디 단독 + 수렴 곡선 (`result_greedy.mat` 생성) |

(통합 파이프라인의 파일명이 한글이 아닌 이유: MATLAB 스크립트명은 영문자 시작·영문/숫자/밑줄만 허용 —
한글 파일명은 `run()` 으로도 실행 불가함을 확인함.)

세 드라이버 모두 **동일 실험 조건**을 `net_config.m`에서 읽는다 (조건 변경 = 그 파일 한 곳만 수정).

## 계층 구조 / 호출 관계

```
net_config.m ────────────── 실험 조건 단일 소스 (maxBaseKm, nOuter)
load_stations.m ─────────── 데이터: shp 로드 + DMS→십진도 (lon, lat, names, 속성테이블)
outer_ring.m ────────────── 최외곽 고정 노드 인덱스 (볼록껍질 12 + YODK)

greedy_area_max.m ───────── 그리디 엔진 래퍼 → greedy_monitor_net.m (통합 엔진, objective='area')
ilp_area_max.m ──────────── ILP 엔진 (후보 열거·C1/C2·Pack/Force + no-good 루프)
   └─ overlap_constraints.m   clique(점-커버리지) 컷 생성

valid_net_wgs84.m ───────── 평가: 유효셀 정확 면적/개수 (WGS84)
save_net_result.m ───────── 표준 결과 struct R → result_greedy.mat / result_ilp.mat
export_result_mat.m ─────── result_*.mat → <maxBaseKm>_result.mat (code/name/isRef/lat/lon/height/proj)
export_assignment.m ─────── result_*.mat → assignment_<method>.csv (배정표 + 전환 목록)

plots/ ──────────────────── 결과 .mat 소비자 (통계·지도·PPT figure). plot_net_map.m 은 드라이버 공용 지도
```

드라이버 흐름: `load_stations` → `net_config`+`outer_ring` → 엔진 → `valid_net_wgs84` → `save_net_result` → export → `plots/plot_net_map`

## 출력 파일

- `result_ilp.mat` / `result_greedy.mat` — 표준 결과 struct `R` (좌표·isRef·names·조건·info)
- `<maxBaseKm>_result.mat` (예: `100_result.mat`) — 관측소 정보 테이블 `stations` (실무용)
- `assignment_ilp.csv` — 역할 배정표 (RINEX, role, lat, lon)
- `stats_result.csv` — plots/run_stats.m 이 생성하는 통계표

## 참고 (legacy, 현재 파이프라인 미사용)

- `run_greedy_count_max.m` — 유효셀 "개수" 최대화 (목적 폐기, 참고용)
- `run_param_sweep.m` — 초기 파라미터 실험
- `*.asv` — MATLAB 자동 저장본
