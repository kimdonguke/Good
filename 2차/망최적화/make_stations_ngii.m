%% make_stations_ngii.m — 최신 고시 기반 관측소 데이터셋(stations_ngii.mat) 생성
%  소스: Data/CORS_coordinate_최종본.xlsx (고시 ECEF X,Y,Z → GRS80 LLH,
%        plots/load_cors_external.m) 중 국토지리정보원 소속 102개소.
%  기존 소스(Data/rts/위성기준점(99개소).shp)는 legacy — 신구 대조 리포트만 출력.
%
%  저장: stations_ngii.mat
%    S    : table 102행 — RINEX / Name(한글, shp 조인; 신설국은 "") / lat / lon /
%           Height(타원체고) / Proj(투영원점, 경도 유도) / status(ok·missing) /
%           src(xyz·xlsx_llh) / qcOkDays2025(연간 QC OK일수; QC 파일 있을 때만)
%    meta : 생성일·소스 파일·규칙 요약
%
%  설계 규칙(load_stations 기본값): status=="ok" 97국만 망 설계에 사용.
%    - status=="missing" 5국(CJDO·GMDO·HSDO·JJNG·ULDO)은 2025년 연간 QC 관측
%      0일의 미가동 신설(도서)국 — 기준국/감시국으로 배정 불가하므로 제외.
%      가동 확인 시 status 갱신 후 본 스크립트 재실행.
%
%  신구 대조 참고(2026-07 실측): 공통 97국 좌표차 중앙 0 m (고시=shp 동일),
%    단 GGEO·SGWI 는 구 shp 좌표가 서로 뒤바뀌어 있던 것으로 확인 — 고시 기준 정정.
%    구망에만 있던 JINJ·YECH 는 최신 고시에서 제외됨.
clear; clc;

% ---- 프로젝트 경로 자동 설정 ----
thisDir = fileparts(mfilename('fullpath'));
if isempty(thisDir); thisDir = pwd; end
projectRoot = thisDir;
while ~isfolder(fullfile(projectRoot, 'Src'))
    parentDir = fileparts(projectRoot);
    if isempty(parentDir) || strcmp(parentDir, projectRoot); projectRoot = thisDir; break; end
    projectRoot = parentDir;
end
ngiiPaths = {thisDir, fullfile(thisDir,'plots'), projectRoot, fullfile(projectRoot,'Src'), ...
    fullfile(projectRoot,'Src','Reference Code'), ...
    fullfile(projectRoot,'Data','rts'), fullfile(projectRoot,'dd')};
for pIdx = 1:numel(ngiiPaths)
    if isfolder(ngiiPaths{pIdx}); addpath(ngiiPaths{pIdx}); end
end
% ---------------------------------

%% 1) 고시 xlsx → NGII 102국
[C, ~] = load_cors_external();
G = C(C.agency == "국토지리정보원", :);
G = sortrows(G, 'station');
n = height(G);
fprintf('고시 xlsx: 국토지리정보원 %d개소 (ok %d / missing %d)\n', ...
    n, nnz(G.status=="ok"), nnz(G.status=="missing"));

% 투영원점: 경도 유도 (서부 124~126 / 중부 126~128 / 동부 128~130 / 동해 130~132)
projOf = @(lonv) string(discretize(lonv, [-inf 126 128 130 inf], ...
    'categorical', {'서부','중부','동부','동해'}));
Proj = projOf(G.lon);

%% 2) 구 shp 조인 (한글 지점명 + 신구 대조 리포트, shp 없으면 생략)
Name = repmat("", n, 1);
try
    old = struct2table(shaperead('위성기준점(99개소).shp'));
    old.Properties.VariableNames = {'Geometry','X_proj','Y_proj','FID1','FID2', ...
        'Name','RINEX','LAT_dms','LON_dms','Height','X1','Y1','Proj','None1','None2'}';
    latP = cellfun(@(x) str2double(strsplit(x,'-')), old.LAT_dms, 'UniformOutput', false);
    lonP = cellfun(@(x) str2double(strsplit(x,'-')), old.LON_dms, 'UniformOutput', false);
    vd = ~cellfun('isempty', latP) & ~cellfun('isempty', lonP);
    old = old(vd, :);
    latO = cellfun(@(x) dms2deg(x'), latP(vd));
    lonO = cellfun(@(x) dms2deg(x'), lonP(vd));
    oldC = string(old.RINEX);

    [tf, loc] = ismember(G.station, oldC);
    Name(tf) = string(old.Name(loc(tf)));

    added   = G.station(~tf);
    removed = setdiff(oldC, G.station);
    fprintf('\n[신구 대조] 구 shp %d국 기준\n', numel(oldC));
    fprintf('  신설(고시에만): %d — %s\n', numel(added), strjoin(added', ', '));
    fprintf('  제외(구망에만): %d — %s\n', numel(removed), strjoin(removed', ', '));
    dM = 1000*deg2km(distance(G.lat(tf), G.lon(tf), latO(loc(tf)), lonO(loc(tf))));
    fprintf('  공통 %d국 좌표차: 중앙 %.2f m / 최대 %.1f m\n', nnz(tf), median(dM), max(dM));
    ci = find(tf); big = find(dM > 50);
    for k = big'
        st = G.station(ci(k));
        fprintf('    >50 m: %s(%s) 고시 (%.4fN %.4fE) vs shp (%.4fN %.4fE) — 고시 채택\n', ...
            st, Name(ci(k)), G.lat(ci(k)), G.lon(ci(k)), latO(loc(ci(k))), lonO(loc(ci(k))));
    end
    % 투영원점 대조 (구 shp의 '종부' 오기는 유도값이 자동 정정)
    pm = tf & Proj ~= strrep(string(old.Proj(max(loc,1))), '종부', '중부');
    if any(pm)
        fprintf('  투영원점 유도값과 shp 불일치: %s (유도값 저장)\n', strjoin(G.station(pm)', ', '));
    end
catch ME
    fprintf('(구 shp 대조 생략: %s)\n', ME.message);
end

%% 3) 연간 QC 가용성 조인 (파일 있을 때만 — 선택적)
%  qcOkDays2025 : 연간 OK 일수 (참고용 — 연중 신설국에 불리)
%  qcAvailQ4    : 2025-Q4(10~12월, 92일) OK 비율 — 설계 규칙(qc_rules)의 판정 기준.
%                 연중 개통국도 현재 가동 능력으로 공정하게 평가된다.
qcOkDays2025 = NaN(n, 1);
qcAvailQ4    = NaN(n, 1);
qcFile = fullfile(projectRoot, 'Data', 'NGII_daily_QC_2025-01-01_2025-12-31.xlsx');
if isfile(qcFile)
    Q = readtable(qcFile, 'Sheet', 'Station Summary', 'VariableNamingRule', 'preserve');
    [tfq, locq] = ismember(G.station, string(Q.Station));
    qcOkDays2025(tfq) = Q.OK(locq(tfq));

    D = readtable(qcFile, 'Sheet', 'Daily QC', 'VariableNamingRule', 'preserve');
    ds = string(D.Station);
    dt = D.Date;
    if ~isdatetime(dt); dt = datetime(string(dt), 'InputFormat', 'yyyy-MM-dd'); end
    inQ4 = dt >= datetime(2025,10,1) & dt <= datetime(2025,12,31);
    isOK = string(D.Status) == "OK";
    nWin = 92;
    for k = 1:n
        m = inQ4 & ds == G.station(k);
        if any(m); qcAvailQ4(k) = nnz(m & isOK) / nWin; end
    end

    low = find(qcOkDays2025 < 330 & G.status == "ok");
    fprintf('\n[QC] 가동국 중 연간 OK<330일: %s\n', ...
        strjoin(compose("%s(%d일)", G.station(low), qcOkDays2025(low))', ', '));
    lowQ = find(qcAvailQ4 < 0.95 & G.status == "ok");
    fprintf('[QC] 가동국 중 Q4 가용률<95%%: %s\n', ...
        strjoin(compose("%s(%.0f%%)", G.station(lowQ), 100*qcAvailQ4(lowQ))', ', '));
else
    fprintf('\n[QC] %s 없음 — qcOkDays2025/qcAvailQ4 = NaN (파일 추가 후 재실행 시 자동 조인)\n', qcFile);
end

%% 3b) 'NGII' 시트 조인 — RsrchMt(2026-07-21) 기준국 선별용 지표 (헤더 없음, 열 위치 고정)
%  Var1=station / Var2=Availability / Var3~5=MP1/2/5 [m] / Var6=SLPS
%  / Var7=Score(문서 산정치 — 재계산 교차검증용) / Var8~10=ECEF / Var18=인접국
%  Score 정의(문서): Q_MPi = min(1, 0.3/MPi), S = (Q1·Q2·Q5)^(1/3) (MP5 없으면 (Q1·Q2)^(1/2))
qcAvail = NaN(n,1); qcMP1 = NaN(n,1); qcMP2 = NaN(n,1); qcMP5 = NaN(n,1);
qcSLPS = NaN(n,1); qcScore = NaN(n,1);
if isfile(qcFile) && any(strcmp(sheetnames(qcFile), 'NGII'))
    J = readtable(qcFile, 'Sheet', 'NGII', 'ReadVariableNames', false);
    [tfj, locj] = ismember(G.station, string(J.Var1));
    qcAvail(tfj) = J.Var2(locj(tfj));
    qcMP1(tfj) = J.Var3(locj(tfj));  qcMP2(tfj) = J.Var4(locj(tfj));  qcMP5(tfj) = J.Var5(locj(tfj));
    qcSLPS(tfj) = J.Var6(locj(tfj));
    fprintf('[QC/NGII] 시트 %d행 중 %d국 매칭 / 시트에 없는 국 %d개(%s)\n', ...
        height(J), nnz(tfj), nnz(~tfj), strjoin(G.station(~tfj)', ', '));

    % 시트 누락 8국(ANSG~CHLW): RsrchMt(2026-07-21) p.9 표 전사.
    % Availability 는 7일 RTCM 제공률이라 Daily QC(RINEX)로 재계산 불가 — 문서가 유일 소스.
    FB = {  % station  avail   MP1    MP2    MP5    SLPS
        'ANSG', 0.000, 0.374, 0.363, NaN,   0.953;
        'BOEN', 0.985, 0.239, 0.298, NaN,   3.398;
        'BONH', 0.985, 0.458, 0.470, 0.472, 12.352;
        'BSNG', 0.980, 0.113, 0.165, 0.131, 2.843;
        'CCSB', 0.979, 0.098, 0.133, 0.124, 1.731;
        'CHEN', 0.981, 0.408, 0.380, 0.452, 5.860;
        'CHJU', 0.985, 0.316, 0.351, 0.357, 3.220;
        'CHLW', 0.985, 0.331, 0.329, NaN,   2.893};
    for r = 1:size(FB,1)
        k = find(G.station == string(FB{r,1}), 1);
        if ~isempty(k) && isnan(qcAvail(k))
            qcAvail(k) = FB{r,2};  qcMP1(k) = FB{r,3};  qcMP2(k) = FB{r,4};
            qcMP5(k)  = FB{r,5};  qcSLPS(k) = FB{r,6};
        end
    end

    % Score 산정 (문서 정의; MP1/MP2 없는 국은 NaN — avail cut 대상이라 실사용 없음)
    valid12 = ~isnan(qcMP1) & ~isnan(qcMP2);
    Q1 = min(1, 0.3./qcMP1);  Q2 = min(1, 0.3./qcMP2);  Q5 = min(1, 0.3./qcMP5);
    has5 = valid12 & ~isnan(qcMP5) & qcMP5 > 0;
    qcScore(has5) = (Q1(has5).*Q2(has5).*Q5(has5)).^(1/3);
    no5 = valid12 & ~has5;
    qcScore(no5) = (Q1(no5).*Q2(no5)).^(1/2);

    % 시트 Var7(문서 산정 Score)과 교차검증 — 시트에 실측 MP가 있는 행만
    sheetScore = NaN(n,1); sheetScore(tfj) = J.Var7(locj(tfj));
    chk = tfj & valid12;
    dS = abs(qcScore(chk) - sheetScore(chk));
    fprintf('[QC/NGII] Score 재계산 vs 시트(실측 MP %d국): 최대차 %.4f\n', nnz(chk), max(dS));
    fprintf('[QC/NGII] Availability<0.95: %d국 — %s\n', nnz(qcAvail < 0.95 | isnan(qcAvail)), ...
        strjoin(G.station(qcAvail < 0.95 | isnan(qcAvail))', ', '));
else
    fprintf('[QC/NGII] 시트 없음 — 선별 지표 = NaN\n');
end

%% 4) 저장
S = table(G.station, Name, G.lat, G.lon, G.hEll, Proj, G.status, G.src, ...
    qcOkDays2025, qcAvailQ4, qcAvail, qcMP1, qcMP2, qcMP5, qcSLPS, qcScore, ...
    'VariableNames', {'RINEX','Name','lat','lon','Height','Proj','status','src', ...
                      'qcOkDays2025','qcAvailQ4','qcAvail','qcMP1','qcMP2','qcMP5','qcSLPS','qcScore'});
meta = struct('created', datestr(now), ...
    'source', 'Data/CORS_coordinate_최종본.xlsx (OBS_HEADER, 고시 ECEF→GRS80)', ...
    'nAll', n, 'nDesign', nnz(S.status == "ok"), ...
    'designRule', 'status=="ok" (미가동 신설국 제외) — load_stations 기본값');
save(fullfile(thisDir, 'stations_ngii.mat'), 'S', 'meta');
fprintf('\n저장: stations_ngii.mat (전체 %d국, 설계용 %d국)\n', meta.nAll, meta.nDesign);
fprintf('미가동(missing) 국: %s\n', strjoin(S.RINEX(S.status=="missing")', ', '));
