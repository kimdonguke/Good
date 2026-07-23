function [isRef, info] = ilp_area_max(lon, lat, maxBaseKm, boundaryShrink, qc)
% ILP_AREA_MAX  빈-외접원 ILP로 감시가능망 "면적" 최대화의 전역최적 (골격 ①)
%
%   [isRef, info] = ilp_area_max(lon, lat, maxBaseKm, boundaryShrink, qc)
%
%   결정변수 x_i∈{0,1}(1=기준국), present_T∈[0,1](후보 삼각형이 Delaunay 셀인지).
%   외접원 특성화로 동적 삼각망을 정적 논리제약으로 변환:
%     present_T <= x_a,x_b,x_c            (세 꼭짓점 모두 기준국)
%     present_T <= 1 - x_p (p∈inCirc(T))  (외접원 비어있음)
%   유효셀 단순화: 삼각형 내부점 ⊆ 외접원 내부 → present=1이면 내부점은 전부 감시국.
%     따라서 목적에는 inTri(T)≠∅ 인 후보만 포함. 목적: max Σ a_T·present_T (a_T=WGS84 면적).
%   100km 제약: 후보 필터 + (선택된 R의 실제 Delaunay에 초과 기선이 있으면) no-good 컷 외부루프.
%
%   qc (선택, qc_rules.m 산출): 가용성(QC) 설계 규칙 —
%     ① 기준국 자격: ~qc.refOK & ~외곽 → x_i=0 고정(감시국 전환 강제; 선형 부등식
%        ub 반영) + 해당 국을 꼭짓점으로 갖는 후보/forcing 삼각형 프루닝.
%        외곽 고정국은 커버리지 구조상 예외(경고 로그만).
%     ② 감시 인정: 후보 셀의 내부점 중 qc.monOK 국만 감시국으로 카운트 —
%        가용성 미달 국만 든 셀은 목적(감시가능 면적)에서 제외.
%     qc 생략/[] 이면 규칙 미적용(legacy 동작).
%
%   요구: Optimization Toolbox (intlinprog, linprog).

    global NGII_ILP_LPONLY %#ok<GVMIS>
    if nargin<3 || isempty(maxBaseKm);      maxBaseKm = 100;    end
    if nargin<4 || isempty(boundaryShrink); boundaryShrink = 0.5; end
    if nargin<5;                            qc = [];             end
    if isempty(which('intlinprog'))
        error('ilp_area_max:noToolbox', 'Optimization Toolbox(intlinprog)가 필요합니다.');
    end
    lon = lon(:); lat = lat(:); N = numel(lon);
    tAll = tic;
    if isscalar(boundaryShrink)
        bndDesc = sprintf('shrink=%g', boundaryShrink);
    else
        bndDesc = sprintf('외곽 고정 %d개', numel(boundaryShrink));
    end
    plog(sprintf('[ILP] 시작 N=%d, maxBaseKm=%g, %s', N, maxBaseKm, bndDesc));

    % 투영 좌표 (면적 계산 전용). 토폴로지(외접원/포함/Delaunay)는 파이프라인과 동일하게
    % 원좌표 (lon,lat) 평면 — delaunayTriangulation(lon,lat)과 일치시켜야 feasible 판정이 맞다.
    lat0 = mean(lat); kx = 111.320*cosd(lat0); ky = 110.574;
    Xp = lon*kx; Yp = lat*ky;

    % 외곽 노드 = 항상 기준국. boundaryShrink: 스칼라=shrink factor, 벡터=명시적 외곽 인덱스
    if isscalar(boundaryShrink)
        bIdx = boundary(lon,lat,boundaryShrink);
    else
        bIdx = boundaryShrink(:);
    end
    isBoundary = false(N,1); isBoundary(bIdx) = true;

    % QC 가용성 규칙 (qc_rules.m 참조; qc=[]이면 미적용)
    refAllowed = true(N,1);  monOK = true(N,1);
    if ~isempty(qc)
        refAllowed = qc.refOK(:) | isBoundary;   % 외곽 고정국은 구조상 예외
        monOK = qc.monOK(:);
        bLow = find(isBoundary & ~qc.refOK(:));
        if ~isempty(bLow)
            plog(sprintf('[ILP] 경고: 외곽 고정국 %s 는 가용성 미달이지만 구조상 기준국 유지', ...
                strjoin(cellstr(num2str(bLow(:))), ',')));
        end
        plog(sprintf('[ILP] QC 규칙: 기준국 부적격 %d국(x=0 고정), 감시 인정 %d/%d국', ...
            nnz(~refAllowed), nnz(monOK), N));
    end

    % grandfather 기선쌍 (초기 전체망 >maxBaseKm)
    DT0 = delaunayTriangulation(lon,lat); E0 = edges(DT0);
    len0 = deg2km(distance(lat(E0(:,1)),lon(E0(:,1)),lat(E0(:,2)),lon(E0(:,2))));
    grandPairs = sort(E0(len0>maxBaseKm,:),2);

    % ================= 후보 삼각형 열거 =================
    tris = nchoosek(1:N, 3);
    vOK = refAllowed(tris(:,1)) & refAllowed(tris(:,2)) & refAllowed(tris(:,3));
    tris = tris(vOK, :);                   % QC 부적격 꼭짓점 포함 triple 프루닝 (x=0 고정이라 무의미)
    d12 = deg2km(distance(lat(tris(:,1)),lon(tris(:,1)),lat(tris(:,2)),lon(tris(:,2))));
    d13 = deg2km(distance(lat(tris(:,1)),lon(tris(:,1)),lat(tris(:,3)),lon(tris(:,3))));
    d23 = deg2km(distance(lat(tris(:,2)),lon(tris(:,2)),lat(tris(:,3)),lon(tris(:,3))));
    ok12 = (d12<=maxBaseKm) | ismember(sort(tris(:,[1 2]),2),grandPairs,'rows');
    ok13 = (d13<=maxBaseKm) | ismember(sort(tris(:,[1 3]),2),grandPairs,'rows');
    ok23 = (d23<=maxBaseKm) | ismember(sort(tris(:,[2 3]),2),grandPairs,'rows');
    good = ok12 & ok13 & ok23;
    badTris = tris(~good, :);          % 초과기선 포함 삼각형 (forcing 대상 후보)
    tris = tris(good, :);
    Mraw = size(tris,1);
    plog(sprintf('[ILP] 후보 good=%d, bad=%d, 전처리 %.1fs', Mraw, size(badTris,1), toc(tAll)));

    % 각 후보: 외접원(inCirc) + 삼각형내부(inTri) + WGS84 면적. 프루닝 후 유지.
    presentTris = zeros(Mraw,3);
    aT = zeros(Mraw,1);
    inCircList = cell(Mraw,1);
    inTriList  = cell(Mraw,1);
    M = 0;
    epsC = 1e-6; tolT = 1e-9;
    for t = 1:Mraw
        a = tris(t,1); b = tris(t,2); c = tris(t,3);
        [ok,ux,uy,r2] = circum(lon(a),lat(a),lon(b),lat(b),lon(c),lat(c));   % 원좌표
        if ~ok; continue; end                          % 퇴화(공선)
        d2 = (lon-ux).^2 + (lat-uy).^2;
        inC = find(d2 < r2 - epsC);
        inC = inC(inC~=a & inC~=b & inC~=c);
        if any(isBoundary(inC)); continue; end          % 외접원에 외곽노드 → present 항상 0
        inT = pointsInTri(lon,lat,a,b,c,tolT);
        inT = inT(inT~=a & inT~=b & inT~=c);
        inT = inT(monOK(inT));                          % QC: 감시 인정 국만 카운트
        if isempty(inT); continue; end                  % (인정) 감시국 없는 셀은 면적목적에 무의미
        % 평면 shoelace 면적(km^2) — winding 무관, 투영좌표. 소삼각형이라 WGS84와 <0.1%.
        Ak = 0.5*abs((Xp(b)-Xp(a))*(Yp(c)-Yp(a)) - (Xp(c)-Xp(a))*(Yp(b)-Yp(a)));
        M = M + 1;
        presentTris(M,:) = [a b c];
        aT(M) = Ak;
        inCircList{M} = inC(:);
        inTriList{M}  = inT(:);
    end
    presentTris = presentTris(1:M,:); aT = aT(1:M);
    inCircList = inCircList(1:M); inTriList = inTriList(1:M);
    plog(sprintf('[ILP] 최종 후보 M=%d (inTri≠∅ & 외곽비포함), 전처리누적 %.1fs', M, toc(tAll)));

    % ================= ILP 조립 =================
    nz = N + M;
    f  = [zeros(N,1); -aT];                 % min -면적
    lb = zeros(nz,1); ub = ones(nz,1);
    lb(isBoundary) = 1; ub(isBoundary) = 1; % 외곽 고정
    ub(~refAllowed) = 0;                    % QC: 기준국 부적격 → 감시국 전환 고정 (x_i <= 0)
    intcon = 1:N;

    Lc = sum(cellfun(@numel,inCircList));
    nR = 3*M + Lc; nnzt = 6*M + 2*Lc;
    ii = zeros(nnzt,1); jj = zeros(nnzt,1); vv = zeros(nnzt,1); bb = zeros(nR,1);
    p = 0; r = 0;
    for t = 1:M
        pv = N+t; abc = presentTris(t,:);
        for k = 1:3
            r = r+1;
            ii(p+1)=r; jj(p+1)=pv; vv(p+1)=1;
            ii(p+2)=r; jj(p+2)=abc(k); vv(p+2)=-1;
            p = p+2;                          % present - x_v <= 0
        end
        ic = inCircList{t};
        for q = 1:numel(ic)
            r = r+1;
            ii(p+1)=r; jj(p+1)=pv;    vv(p+1)=1;
            ii(p+2)=r; jj(p+2)=ic(q); vv(p+2)=1;
            p = p+2; bb(r)=1;                 % present + x_p <= 1
        end
    end
    A = sparse(ii,jj,vv,nR,nz); b_ineq = bb;

    % ---- 점별 패킹 제약: 각 관측소는 최대 1개 유효셀에만 속함 (LP 강화) ----
    stTris = cell(N,1);
    for t = 1:M
        for pp = inTriList{t}'
            stTris{pp}(end+1) = t; %#ok<AGROW>
        end
    end
    ip=[]; jp=[]; vp=[]; bp=[]; rp=0;
    for pp = 1:N
        lst = stTris{pp};
        if numel(lst) >= 2
            rp = rp+1;
            ip = [ip, repmat(rp,1,numel(lst))]; %#ok<AGROW>
            jp = [jp, N+lst];                   %#ok<AGROW>
            vp = [vp, ones(1,numel(lst))];      %#ok<AGROW>
            bp(rp,1) = 1;                        %#ok<AGROW>
        end
    end
    if rp>0
        A = [A; sparse(ip,jp,vp,rp,nz)]; b_ineq = [b_ineq; bp];
    end
    plog(sprintf('[ILP] 모델조립: 변수 %d(x%d+present%d), 제약 %d행(+패킹%d), %.1fs', nz, N, M, size(A,1), rp, toc(tAll)));

    % ---- 100km 강제(forcing): bad triple이 Delaunay 셀이 되는 것 금지 ----
    %   x_i+x_j+x_k - Σ_{p∈inCirc} x_p <= 2  (외접원에 외곽노드 있으면 자동만족→프루닝)
    tF = tic; nB = size(badTris,1);
    aX=lon(badTris(:,1)); aY=lat(badTris(:,1)); bX=lon(badTris(:,2)); bY=lat(badTris(:,2));
    cX=lon(badTris(:,3)); cY=lat(badTris(:,3));
    dd = 2*(aX.*(bY-cY)+bX.*(cY-aY)+cX.*(aY-bY));
    nondeg = abs(dd)>1e-12;
    a2=aX.^2+aY.^2; b2=bX.^2+bY.^2; c2=cX.^2+cY.^2;
    uxB=(a2.*(bY-cY)+b2.*(cY-aY)+c2.*(aY-bY))./dd;
    uyB=(a2.*(cX-bX)+b2.*(aX-cX)+c2.*(bX-aX))./dd;
    r2B=(aX-uxB).^2+(aY-uyB).^2;
    insideB = false(nB,1);
    for p = find(isBoundary)'
        insideB = insideB | ((lon(p)-uxB).^2+(lat(p)-uyB).^2 < r2B - epsC);
    end
    surv = find(nondeg & ~insideB);
    plog(sprintf('[ILP] forcing 대상 bad triple: %d/%d (%.1fs)', numel(surv), nB, toc(tF)));
    if_=zeros(numel(surv)*20,1); jf=if_; vf=if_; bf=zeros(numel(surv),1); q=0; rf=0;
    for s = surv'
        d2 = (lon-uxB(s)).^2 + (lat-uyB(s)).^2;
        inC = find(d2 < r2B(s) - epsC);
        abc = badTris(s,:);
        inC = inC(inC~=abc(1) & inC~=abc(2) & inC~=abc(3));
        cols = [abc(:); inC]; vals = [1;1;1; -ones(numel(inC),1)];
        m = numel(cols); rf=rf+1;
        if q+m > numel(if_); if_(end+2*m)=0; jf(end+2*m)=0; vf(end+2*m)=0; end
        if_(q+1:q+m)=rf; jf(q+1:q+m)=cols; vf(q+1:q+m)=vals; q=q+m; bf(rf)=2;
    end
    if rf>0
        A = [A; sparse(if_(1:q),jf(1:q),vf(1:q),rf,nz)]; b_ineq = [b_ineq; bf(1:rf)];
    end
    plog(sprintf('[ILP] forcing 제약 %d행 추가, 총제약 %d (%.1fs)', rf, size(A,1), toc(tAll)));

    % ---- overlap/clique 제약 (겹치는 후보 삼각형 동시선택 금지: 퇴화 해소 + LP 강화) ----
    tO = tic;
    [Aov, bov, nClq] = overlap_constraints(presentTris, lon, lat, N);
    A = [A; Aov]; 
    b_ineq = [b_ineq; bov];
    plog(sprintf('[ILP] overlap(clique) 제약 %d행 추가, 총제약 %d (%.1fs)', nClq, size(A,1), toc(tO)));

    % ---- LP 완화 상한 (dual bound) ----
    tLP = tic;
    lpOpts = optimoptions('linprog','Display','iter');
    [~,fvalLP] = linprog(f, A, b_ineq, [], [], lb, ub, lpOpts);
    lpBound = -fvalLP;
    plog(sprintf('[ILP] LP 상한 = %.1f km^2 (%.1fs)', lpBound, toc(tLP)));

    if ~isempty(NGII_ILP_LPONLY) && NGII_ILP_LPONLY
        plog('[ILP] LPONLY 모드 → intlinprog 생략, 조기 반환');
        isRef = isBoundary;
        info = struct('nCandRaw',Mraw,'nCand',M,'lpBound_km2',lpBound, ...
                      'ilpObj_km2',NaN,'iters',0,'isBoundary',isBoundary, ...
                      'grandPairs',grandPairs,'maxBaseKm',maxBaseKm);
        return;
    end

    % ---- ILP + no-good 컷 외부루프 (100km 실현가능성 보증) ----
    ipOpts = optimoptions('intlinprog','Display','iter','MaxTime',600,'RelativeGapTolerance',1e-4);   % 200→600 (탐색공간 확대 대응, 3배)
    Ang = sparse(0,nz); bng = zeros(0,1);
    isRef = isBoundary; iters = 0; ilpObj = NaN; ilpGap = NaN;
    for iter = 1:2
        iters = iter; tIt = tic;
        [z,fval,ef,out] = intlinprog(f, intcon, [A;Ang], [b_ineq;bng], [], [], lb, ub, ipOpts);
        if isempty(z) || ef<=0
            plog(sprintf('[ILP] iter %d: intlinprog 미해결 exitflag=%d (%.1fs)', iter, ef, toc(tIt)));
            if isempty(z); break; end
        end
        x = round(z(1:N)); R = find(x>0.5);
        isRef = false(N,1); isRef(R) = true;
        ilpObj = -fval;
        if isfield(out,'relativegap'); ilpGap = out.relativegap; end
        feas = configFeasLocal(lon,lat,isRef,maxBaseKm,grandPairs);
        plog(sprintf('[ILP] iter %d: obj=%.1f, 기준국=%d, feasible=%d, exitflag=%d (%.1fs)', ...
            iter, ilpObj, numel(R), feas, ef, toc(tIt)));
        if feas; break; end
        row = sparse(1,nz); row(1,R)=1; row(1,setdiff((1:N)',R))=-1;   % no-good: 이 R 금지
        Ang = [Ang; row]; bng = [bng; numel(R)-1]; %#ok<AGROW>
    end
    plog(sprintf('[ILP] 완료: 총 %.1fs, no-good %d회', toc(tAll), iters));

    info = struct('nCandRaw',Mraw,'nCand',M,'lpBound_km2',lpBound, ...
                  'ilpObj_km2',ilpObj,'ilpGap',ilpGap,'iters',iters,'isBoundary',isBoundary, ...
                  'grandPairs',grandPairs,'maxBaseKm',maxBaseKm, ...
                  'qcForcedIdx',find(~refAllowed),'monOK',monOK);
end

% ======================================================================
function plog(msg)
    fprintf('%s\n', msg);
    pf = getenv('NGII_PROGRESS_FILE');
    if ~isempty(pf)
        fid = fopen(pf,'a');
        if fid>0; fprintf(fid,'%s\n',msg); fclose(fid); end
    end
end

% ======================================================================
function [ok,ux,uy,r2] = circum(ax,ay,bx,by,cx,cy)
    d = 2*(ax*(by-cy)+bx*(cy-ay)+cx*(ay-by));
    if abs(d) < 1e-9; ok=false; ux=0; uy=0; r2=0; return; end
    a2=ax^2+ay^2; b2=bx^2+by^2; c2=cx^2+cy^2;
    ux = (a2*(by-cy)+b2*(cy-ay)+c2*(ay-by))/d;
    uy = (a2*(cx-bx)+b2*(ax-cx)+c2*(bx-ax))/d;
    r2 = (ax-ux)^2+(ay-uy)^2; ok = true;
end

% ======================================================================
function idx = pointsInTri(X,Y,a,b,c,tol)
    x1=X(a);y1=Y(a);x2=X(b);y2=Y(b);x3=X(c);y3=Y(c);
    d = (y2-y3).*(x1-x3) + (x3-x2).*(y1-y3);
    l1 = ((y2-y3).*(X-x3) + (x3-x2).*(Y-y3))/d;
    l2 = ((y3-y1).*(X-x3) + (x1-x3).*(Y-y3))/d;
    l3 = 1 - l1 - l2;
    idx = find(l1>tol & l2>tol & l3>tol);
end

% ======================================================================
function feas = configFeasLocal(lon,lat,isRef,maxBaseKm,grandPairs)
    R = find(isRef); lonR=lon(R); latR=lat(R);
    if numel(R)<3; feas=false; return; end
    DT = delaunayTriangulation(lonR,latR); E = edges(DT);
    lenKm = deg2km(distance(latR(E(:,1)),lonR(E(:,1)),latR(E(:,2)),lonR(E(:,2))));
    bad = lenKm>maxBaseKm;
    if ~any(bad); feas=true; return; end
    feas = all(ismember(sort(R(E(bad,:)),2), grandPairs, 'rows'));
end
