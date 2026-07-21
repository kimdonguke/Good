%% 망 최적화 결과 분석 - 통계 + 플롯 (초기 / 그리디 / ILP 비교)
%  저장된 결과(result_greedy.mat, result_ilp.mat)를 로드. 헤드리스 안전(평면 플롯).
close all; clear; clc;

% ---- 프로젝트 경로 자동 설정 ----
thisDir = fileparts(mfilename('fullpath'));
if isempty(thisDir); thisDir = pwd; end
projectRoot = thisDir;
while ~isfolder(fullfile(projectRoot, 'Src'))
    parentDir = fileparts(projectRoot);
    if isempty(parentDir) || strcmp(parentDir, projectRoot); projectRoot = thisDir; break; end
    projectRoot = parentDir;
end
optDir = fileparts(thisDir);            % 망최적화 폴더 (알고리즘·결과 파일)
ngiiPaths = {thisDir, optDir, projectRoot, fullfile(projectRoot,'Src'), ...
    fullfile(projectRoot,'Src','Reference Code'), fullfile(projectRoot,'Data','rts'), fullfile(projectRoot,'dd')};
for pIdx = 1:numel(ngiiPaths)
    if isfolder(ngiiPaths{pIdx}); addpath(ngiiPaths{pIdx}); end
end
% ---------------------------------

%% 저장된 결과 로드 (그리디 + ILP)
fG = fullfile(optDir,'result_greedy.mat');
fI = fullfile(optDir,'result_ilp.mat');
if ~isfile(fG); error('그리디 결과 없음: %s (run_greedy_area_max.m 먼저 실행)', fG); end
if ~isfile(fI); error('ILP 결과 없음: %s (run_ilp_area_max.m 먼저 실행)', fI); end
Lg = load(fG); Rg = Lg.R;
Li = load(fI); Ri = Li.R;
lon = Rg.lon; lat = Rg.lat; N = numel(lon);

maxBaseKm = Rg.maxBaseKm;   % 결과 파일과 동일 기준 사용 (기선 상한/grandfather 판정)
if Rg.maxBaseKm ~= Ri.maxBaseKm
    warning('그리디(%d km)와 ILP(%d km)의 maxBaseKm이 다릅니다 — 비교가 불공정할 수 있음.', ...
        Rg.maxBaseKm, Ri.maxBaseKm);
end

%% 통계 (초기 전체망 / 그리디 / ILP)
Sb = net_stats(lon, lat, true(N,1), maxBaseKm);   % 초기(감시국 0)
Sg = net_stats(lon, lat, Rg.isRef,  maxBaseKm);   % 그리디
Si = net_stats(lon, lat, Ri.isRef,  maxBaseKm);   % ILP

%% 통계 출력 (한글 폭 정렬)
fprintf('\n===== 망 최적화 결과 통계 (초기 / 그리디 / ILP) =====\n');
row3('항목','초기(99)','그리디','ILP');
fprintf('%s\n', repmat('-',1,64));
row3('기준국 수',            i2(Sb.nRef),      i2(Sg.nRef),      i2(Si.nRef));
row3('감시국 수',            i2(Sb.nMon),      i2(Sg.nMon),      i2(Si.nMon));
row3('기선(edge) 수',        i2(Sb.bl_n),      i2(Sg.bl_n),      i2(Si.bl_n));
row3('기선 평균-전체(km)',   f1(Sb.bl_mean),   f1(Sg.bl_mean),   f1(Si.bl_mean));
row3('기선 평균-초과제외',   f1(Sb.blx_mean),  f1(Sg.blx_mean),  f1(Si.blx_mean));
row3('기선 중앙-전체(km)',   f1(Sb.bl_med),    f1(Sg.bl_med),    f1(Si.bl_med));
row3('기선 중앙-초과제외',   f1(Sb.blx_med),   f1(Sg.blx_med),   f1(Si.blx_med));
row3('기선 최대-전체(km)',   f1(Sb.bl_max),    f1(Sg.bl_max),    f1(Si.bl_max));
row3('기선 최대-초과제외',   f1(Sb.blx_max),   f1(Sg.blx_max),   f1(Si.blx_max));
row3(sprintf('초기>%dkm 엣지 수',maxBaseKm), i2(Sb.bl_nGrand), i2(Sg.bl_nGrand), i2(Si.bl_nGrand));
row3(sprintf('현재>%dkm 엣지 수',maxBaseKm), i2(Sb.bl_over),   i2(Sg.bl_over),   i2(Si.bl_over));
row3('전체 셀 수',           i2(Sb.nTotalCells), i2(Sg.nTotalCells), i2(Si.nTotalCells));
row3('유효셀 수',            '-',              i2(Sg.nValidCells), i2(Si.nValidCells));
row3('감시가능 면적(km^2)',  '-',              f0(Sg.coverage_km2), f0(Si.coverage_km2));
row3('  └ 국토 대비(%)',     '-',              f1(Sg.cover_vs_korea), f1(Si.cover_vs_korea));
row3('유효셀 평균면적(km^2)','-',              f0(Sg.cell_mean),  f0(Si.cell_mean));
row3('셀당 감시국(평균)',    '-',              f2(mean0(Sg.monPerCell)), f2(mean0(Si.monPerCell)));
fprintf('%s\n\n', repmat('-',1,64));

% CSV 저장 (초기/그리디/ILP)
T = table(["기준국";"감시국";"기선수";"기선평균전체";"기선평균초과제외";"기선최대전체"; ...
           "기선최대초과제외";sprintf("초기>%dkm수",maxBaseKm);"유효셀";"면적km2"], ...
    [Sb.nRef;Sb.nMon;Sb.bl_n;Sb.bl_mean;Sb.blx_mean;Sb.bl_max;Sb.blx_max;Sb.bl_nGrand;0;0], ...
    [Sg.nRef;Sg.nMon;Sg.bl_n;Sg.bl_mean;Sg.blx_mean;Sg.bl_max;Sg.blx_max;Sg.bl_nGrand;Sg.nValidCells;Sg.coverage_km2], ...
    [Si.nRef;Si.nMon;Si.bl_n;Si.bl_mean;Si.blx_mean;Si.bl_max;Si.blx_max;Si.bl_nGrand;Si.nValidCells;Si.coverage_km2], ...
    'VariableNames',{'metric','init','greedy','ilp'});
writetable(T, fullfile(optDir,'stats_result.csv'));

%% 플롯 A: 4패널 (초기/그리디/ILP)
fA = figure('Name','망 최적화 통계','Color','w','Position',[80 80 1200 900]);
tl = tiledlayout(2,2,'TileSpacing','compact','Padding','compact');
title(tl,sprintf('망 최적화 결과 분석 (초기 / 그리디 / ILP, 초기>%dkm 기선 제외)', maxBaseKm));

nexttile; hold on;   % 기선장 히스토그램
histogram(Sb.baselines_ex,'BinWidth',10,'FaceColor',[0.4 0.6 0.9],'FaceAlpha',0.45,'DisplayName','초기(99)');
histogram(Sg.baselines_ex,'BinWidth',10,'FaceColor',[0.9 0.5 0.3],'FaceAlpha',0.45,'DisplayName','그리디');
histogram(Si.baselines_ex,'BinWidth',10,'FaceColor',[0.3 0.7 0.4],'FaceAlpha',0.45,'DisplayName','ILP');
xline(maxBaseKm,'r--','LineWidth',1.2,'HandleVisibility','off');
xlabel('기선장 (km)'); ylabel('개수'); title('기선장 분포'); legend('Location','northeast'); grid on; hold off;

nexttile; hold on;   % CDF
cdfplot_(Sb.baselines_ex,[0.2 0.4 0.8],'초기(99)');
cdfplot_(Sg.baselines_ex,[0.85 0.4 0.15],'그리디');
cdfplot_(Si.baselines_ex,[0.15 0.6 0.25],'ILP');
xline(maxBaseKm,'r--','LineWidth',1.2,'HandleVisibility','off');
xlabel('기선장 (km)'); ylabel('누적확률'); title('기선장 CDF'); legend('Location','southeast'); grid on; hold off;

nexttile; hold on;   % 유효셀 면적
histogram(Sg.cellAreas,'BinWidth',300,'FaceColor',[0.9 0.5 0.3],'FaceAlpha',0.5,'DisplayName','그리디');
histogram(Si.cellAreas,'BinWidth',300,'FaceColor',[0.3 0.7 0.4],'FaceAlpha',0.5,'DisplayName','ILP');
xlabel('유효셀 면적 (km^2)'); ylabel('개수'); title('유효셀 면적 분포'); legend('Location','northeast'); grid on; hold off;

nexttile;            % 커버 면적 비교
bar(categorical({'그리디','ILP'},{'그리디','ILP'}), [Sg.coverage_km2, Si.coverage_km2], 0.5, 'FaceColor',[0.4 0.6 0.9]);
ylabel('감시가능 면적 (km^2)'); grid on; title('감시가능 면적 비교');
text(1:2,[Sg.coverage_km2,Si.coverage_km2],compose('%.0f',[Sg.coverage_km2,Si.coverage_km2]), ...
     'HorizontalAlignment','center','VerticalAlignment','bottom');

% ---- 플롯 A 즉시 저장 (핸들 stale/창닫힘 방지) ----
figSave = fullfile(optDir,'result_fig','01_망설계');   % figure는 작업단위별 하위 폴더에 저장
if ~isfolder(figSave); mkdir(figSave); end
drawnow;
if isgraphics(fA)
    print(fA, fullfile(figSave,'stats_panels.png'), '-dpng', '-r200');
else
    warning('플롯 A 핸들이 유효하지 않아 저장을 건너뜁니다.');
end

%% 플롯 B: ILP 커버리지 지도 (평면, geobasemap 미사용)
fB = figure('Name','ILP 커버리지 지도','Color','w','Position',[80 80 960 720]);
hold on; axis equal;
CLp=Si.CL; lonRp=Si.lonR; latRp=Si.latR;
patch('Faces',CLp,'Vertices',[lonRp latRp],'FaceColor',[0.88 0.88 0.88],'EdgeColor',[0.4 0.4 0.4],'LineWidth',0.3);
patch('Faces',CLp(Si.validCells,:),'Vertices',[lonRp latRp],'FaceColor',[1 0.35 0.35],'FaceAlpha',0.55,'EdgeColor','k','LineWidth',0.4);
plot(lonRp,latRp,'ks','MarkerFaceColor','y','MarkerSize',7);
plot(Si.lonM,Si.latM,'k^','MarkerFaceColor','b','MarkerSize',6);
xlabel('경도(°)'); ylabel('위도(°)'); grid on;
legend({'전체 셀','유효셀','기준국','감시국'},'Location','northeast');
title(sprintf('[ILP] 커버리지 (기준국 %d, 감시국 %d, %.0f km^2)', Si.nRef, Si.nMon, Si.coverage_km2));
xlim([124.5 130.5]); ylim([33.5 38.8]); hold off;

% ---- 플롯 B 즉시 저장 ----
drawnow;
if isgraphics(fB)
    print(fB, fullfile(figSave,'stats_coverage_map.png'), '-dpng', '-r200');
else
    warning('플롯 B 핸들이 유효하지 않아 저장을 건너뜁니다 (창이 닫혔을 수 있음).');
end
fprintf('그림 저장: %s\n', figSave);

% ======================================================================
function s2 = padk(s, w)         % 한글(넓은 문자)을 2칸으로 계산해 좌측정렬 패딩
    cw = numel(s) + sum(double(s) > 127);
    s2 = [s, repmat(' ', 1, max(0, w - cw))];
end
function row3(lbl, a, b, c)
    fprintf('%s%s%s%s\n', padk(lbl,26), padk(a,12), padk(b,12), padk(c,12));
end
function s = i2(x); s = sprintf('%d', x); end
function s = f0(x); s = sprintf('%.0f', x); end
function s = f1(x); s = sprintf('%.1f', x); end
function s = f2(x); s = sprintf('%.2f', x); end
function m = mean0(v); if isempty(v); m = 0; else; m = mean(v); end; end
function cdfplot_(v, col, name)
    p = sort(v(:)); plot(p, (1:numel(p))/numel(p), '-', 'LineWidth',1.5, 'Color',col, 'DisplayName',name);
end
