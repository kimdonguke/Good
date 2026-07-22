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
qcOkDays2025 = NaN(n, 1);
qcFile = fullfile(projectRoot, 'Data', 'NGII_daily_QC_2025-01-01_2025-12-31.xlsx');
if isfile(qcFile)
    Q = readtable(qcFile, 'Sheet', 'Station Summary', 'VariableNamingRule', 'preserve');
    [tfq, locq] = ismember(G.station, string(Q.Station));
    qcOkDays2025(tfq) = Q.OK(locq(tfq));
    low = find(qcOkDays2025 < 330 & G.status == "ok");
    fprintf('\n[QC] 가동국 중 연간 OK<330일: %s\n', ...
        strjoin(compose("%s(%d일)", G.station(low), qcOkDays2025(low))', ', '));
else
    fprintf('\n[QC] %s 없음 — qcOkDays2025 = NaN (파일 추가 후 재실행 시 자동 조인)\n', qcFile);
end

%% 4) 저장
S = table(G.station, Name, G.lat, G.lon, G.hEll, Proj, G.status, G.src, qcOkDays2025, ...
    'VariableNames', {'RINEX','Name','lat','lon','Height','Proj','status','src','qcOkDays2025'});
meta = struct('created', datestr(now), ...
    'source', 'Data/CORS_coordinate_최종본.xlsx (OBS_HEADER, 고시 ECEF→GRS80)', ...
    'nAll', n, 'nDesign', nnz(S.status == "ok"), ...
    'designRule', 'status=="ok" (미가동 신설국 제외) — load_stations 기본값');
save(fullfile(thisDir, 'stations_ngii.mat'), 'S', 'meta');
fprintf('\n저장: stations_ngii.mat (전체 %d국, 설계용 %d국)\n', meta.nAll, meta.nDesign);
fprintf('미가동(missing) 국: %s\n', strjoin(S.RINEX(S.status=="missing")', ', '));
