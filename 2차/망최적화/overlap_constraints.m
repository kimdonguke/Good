function [Acl, bcl, nClq] = overlap_constraints(presentTris, lon, lat, N)
% OVERLAP_CONSTRAINTS  점-커버리지 clique 제약: 한 점을 내부에 포함하는 후보 삼각형은
%   최대 1개만 present.  Σ_{T: q∈int(T)} present_T <= 1   (질의점 q마다)
%
%   [Acl, bcl, nClq] = overlap_constraints(presentTris, lon, lat, N)
%
%   왜 pairwise(present_T+present_T'<=1)가 아니라 clique인가:
%     - pairwise 는 정수해에선 겹침을 막지만(퇴화 해소), LP에선 present=0.5로 다 빠져나가
%       상한을 못 조인다.
%     - clique(한 점 위 삼각형 합<=1)는 분수해 0.5 남발도 막아 LP 상한을 크게 조이고,
%       정수해에선 그 점에서 겹치는 삼각형을 하나로 강제(퇴화도 해소).
%   질의점 q = 후보 삼각형의 중심 + 3변 중점 (겹침이 잦은 지점을 촘촘히 샘플).
%   valid inequality(모든 실제 망이 만족: 한 점은 Delaunay 셀 하나에만 속함) → 정수해 보존.
%
%   반환: 희소 부등식 A_cl * z <= b_cl  (z = [x(1:N); present(1:M)]).

    lon = lon(:); lat = lat(:);
    M = size(presentTris,1); nz = N + M;
    ax=lon(presentTris(:,1)); ay=lat(presentTris(:,1));
    bx=lon(presentTris(:,2)); by=lat(presentTris(:,2));
    cx=lon(presentTris(:,3)); cy=lat(presentTris(:,3));

    % 질의점: 중심 + 3변 중점
    Qx = [ (ax+bx+cx)/3; (ax+bx)/2; (bx+cx)/2; (cx+ax)/2 ];
    Qy = [ (ay+by+cy)/3; (ay+by)/2; (by+cy)/2; (cy+ay)/2 ];
    nQ = numel(Qx);

    cliques = cell(nQ,1);
    for k = 1:nQ
        ins = find(pInT(Qx(k),Qy(k), ax,ay,bx,by,cx,cy));   % q를 내부에 포함하는 삼각형들
        if numel(ins) >= 2
            cliques{k} = sort(ins(:))';
        end
    end
    cliques = cliques(~cellfun('isempty', cliques));

    % 중복 clique 제거
    keys = cellfun(@(c) sprintf('%d,', c), cliques, 'UniformOutput', false);
    [~, ia] = unique(keys);
    cliques = cliques(ia);
    nClq = numel(cliques);

    % 조립
    rows = cell(nClq,1); cols = cell(nClq,1);
    for r = 1:nClq
        c = cliques{r};
        rows{r} = repmat(r, numel(c), 1);
        cols{r} = (N + c)';
    end
    rows = vertcat(rows{:}); cols = vertcat(cols{:});
    Acl = sparse(rows, cols, ones(numel(rows),1), nClq, nz);
    bcl = ones(nClq,1);
end

% ======================================================================
function tf = pInT(px,py, x1,y1,x2,y2,x3,y3)   % 점이 삼각형 strict 내부?
    d  = (y2-y3).*(x1-x3) + (x3-x2).*(y1-y3);
    l1 = ((y2-y3).*(px-x3) + (x3-x2).*(py-y3))./d;
    l2 = ((y3-y1).*(px-x3) + (x1-x3).*(py-y3))./d;
    l3 = 1 - l1 - l2;
    tf = (l1 > 1e-12) & (l2 > 1e-12) & (l3 > 1e-12);
end
