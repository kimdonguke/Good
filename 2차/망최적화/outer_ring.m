function idx = outer_ring(lon, lat, nTarget)
% OUTER_RING  최외곽 노드 nTarget개의 인덱스 반환.
%   볼록껍질(convhull) 노드를 기본으로 하고, 개수가 부족하면
%   껍질 경계에 가장 가까운 비(非)껍질 점을 순서대로 채워 정확히 nTarget개를 만든다.
%   (예: 한국 위성기준점 99개 → convhull 12개, nTarget=13이면 동해안 YODK가 13번째로 추가)
%
%   idx = outer_ring(lon, lat, nTarget)
    lon = lon(:); lat = lat(:); N = numel(lon);
    ch = unique(convhull(lon, lat), 'stable');
    if nargin < 3 || isempty(nTarget) || nTarget <= numel(ch)
        idx = ch; return;
    end
    nTarget = min(nTarget, N);
    rest = setdiff((1:N)', ch);
    px = lon(ch); py = lat(ch); nh = numel(ch);
    d = inf(numel(rest), 1);
    for k = 1:numel(rest)
        p = [lon(rest(k)) lat(rest(k))]; best = inf;
        for e = 1:nh
            a = [px(e) py(e)];
            j = mod(e, nh) + 1; b = [px(j) py(j)];
            ab = b - a; tt = max(0, min(1, dot(p-a, ab)/max(dot(ab, ab), eps)));
            pr = a + tt*ab; best = min(best, norm(p - pr));
        end
        d(k) = best;
    end
    [~, ord] = sort(d);
    need = nTarget - numel(ch);
    idx = [ch; rest(ord(1:need))];
end
