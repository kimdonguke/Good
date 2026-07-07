%% ILP_FLOWCHART  빈-외접원 ILP 면적 최대화 순서도 생성 (PPT용)
%  그리디 flowchart(greedy_flowchart.png)와 같은 스타일의 박스/다이아몬드 순서도.
%  실행하면 figure_for_ppt/ilp_flowchart.png 로 저장된다.
clear; clc; close all;

thisDir = fileparts(mfilename('fullpath'));
if isempty(thisDir); thisDir = pwd; end
optDir = fileparts(thisDir);
figDir = fullfile(optDir, 'figure_for_ppt');
if ~isfolder(figDir); mkdir(figDir); end

figure('Color','w','Position',[100 60 760 940]);
ax = axes('Position',[0 0 1 1]); hold(ax,'on');
xlim([0 1]); ylim([0 1]); axis off;

BLUE = [0.27 0.45 0.77];     % 테두리/화살표 (원본 flowchart 톤)
W  = 0.60;  H = 0.072;       % 박스 크기
cx = 0.46;                   % 중심 x (오른쪽에 루프백 여유)

title(ax, '기준국 망 구성 최적화 — 정수선형계획(ILP)', ...
    'FontSize',13, 'FontWeight','bold');

% ---- 세로 배치 y좌표 ----
y = linspace(0.90, 0.06, 7);

txt = { ...
  {'후보 삼각형 열거', '모든 3조합 156,849 → 기선 \leq100km 필터 → 3,665'}, ...
  {'기하 사전계산: 외접원(inCirc)·내부점(inTri)', '프루닝(외곽포함·빈셀 제외) → 후보 1,539 + 면적 a_T'}, ...
  {'MILP 조립:  변수 x_i(기준국), present_T', '제약 C1(꼭짓점)·C2(빈 외접원)·Pack·Forcing·Clique'}, ...
  {'LP 완화 풀이 (linprog)', '\rightarrow 상한(dual bound) 확보'}, ...
  {'분기한정 (intlinprog)', '분기 + LP상한 가지치기 \rightarrow 정수해 x^* 탐색'}, ...
  {'실제 들로네 재검증', '신규 >100km 기선 없음?'}, ...              % ◇
  {'최적 망 확정 (전역최적)', '기준국/감시국 배정 \rightarrow result\_ilp.mat'} };

% ---- 박스/다이아몬드 그리기 ----
for k = 1:7
    if k == 6
        drawDiamond(ax, cx, y(k), W*0.88, H*2.1, txt{k}, BLUE);
    else
        drawBox(ax, cx, y(k), W, H, txt{k}, BLUE);
    end
end

% ---- 세로 화살표 (박스 사이) ----
for k = 1:6
    y1 = y(k) - H/2;  y2 = y(k+1) + H/2;
    if k == 5; y1 = y(k) - H/2; y2 = y(6) + H*1.05; end     % 박스5 → 다이아
    if k == 6; y1 = y(6) - H*1.05; y2 = y(7) + H/2; end     % 다이아 → 박스7
    drawArrow(ax, cx, y1, cx, y2, BLUE);
end
text(cx+0.02, (y(6)-H*1.05 + y(7)+H/2)/2, '예(통과)', 'Color',BLUE, 'FontSize',9);

% ---- 루프백: 다이아(아니오) → no-good 컷 → 분기한정(5) ----
xr = cx + W*0.88/2;            % 다이아 오른쪽 꼭짓점
xR = 0.90;                     % 우측 루프 x
plot(ax, [xr xR], [y(6) y(6)], '-', 'Color',BLUE, 'LineWidth',1.4);
plot(ax, [xR xR], [y(6) y(5)], '-', 'Color',BLUE, 'LineWidth',1.4);
drawArrow(ax, xR, y(5), cx+W/2, y(5), BLUE);
text(xR+0.005, (y(6)+y(5))/2, {'아니오:','no-good','컷 추가'}, ...
    'Color',BLUE, 'FontSize',9, 'HorizontalAlignment','left');

print(gcf, fullfile(figDir,'ilp_flowchart.png'), '-dpng', '-r220');
fprintf('저장: %s\n', fullfile(figDir,'ilp_flowchart.png'));

% ========================================================================
function drawBox(ax, cx, cy, w, h, lines, col)
    rectangle(ax, 'Position',[cx-w/2, cy-h/2, w, h], 'EdgeColor',col, ...
        'LineWidth',1.6, 'FaceColor','w');
    putText(ax, cx, cy, lines);
end

function drawDiamond(ax, cx, cy, w, h, lines, col)
    patch(ax, cx + [0 w/2 0 -w/2], cy + [h/2 0 -h/2 0], 'w', ...
        'EdgeColor',col, 'LineWidth',1.6);
    putText(ax, cx, cy, lines);
end

function putText(ax, cx, cy, lines)
    text(ax, cx, cy+0.012, lines{1}, 'HorizontalAlignment','center', ...
        'FontSize',10.5, 'FontWeight','bold');
    text(ax, cx, cy-0.016, lines{2}, 'HorizontalAlignment','center', ...
        'FontSize',9, 'Color',[0.25 0.25 0.25]);
end

function drawArrow(ax, x1, y1, x2, y2, col)
    plot(ax, [x1 x2], [y1 y2], '-', 'Color',col, 'LineWidth',1.4);
    % 화살촉
    v = [x2-x1, y2-y1]; v = v / max(norm(v), eps);
    n = [-v(2), v(1)];  s = 0.013;
    patch(ax, [x2, x2-s*v(1)+0.6*s*n(1), x2-s*v(1)-0.6*s*n(1)], ...
              [y2, y2-s*v(2)+0.6*s*n(2), y2-s*v(2)-0.6*s*n(2)], col, 'EdgeColor','none');
end
