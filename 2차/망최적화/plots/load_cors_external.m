function [T, Raw] = load_cors_external()
% LOAD_CORS_EXTERNAL  상설 감시국 고시좌표 로드 + ECEF→LLH 변환
%   데이터: Data/CORS_coordinate_최종본.xlsx, 시트 OBS_HEADER (225국, 기관 8곳)
%   고시좌표 X,Y,Z(ECEF)를 GRS80 타원체 측지좌표로 변환한다 (KGD2002 정의 타원체).
%
%   출력 T  : station(코드) / agency(담당기관) / status(ok·missing) /
%             lat, lon [deg] / hEll [m, 타원체고]
%        Raw: 원본 테이블 (xlsx 의 참고용 Lat/Lon/Height 열 포함 — 변환 검증용)
%
%   비고: 국토지리정보원 소속국(우리 위성기준점 계열)도 포함되어 있으므로
%         "외부" 기관만 쓰려면 T.agency ~= "국토지리정보원" 으로 필터할 것.

    thisDir = fileparts(mfilename('fullpath'));
    if isempty(thisDir); thisDir = pwd; end
    projectRoot = thisDir;
    while ~isfolder(fullfile(projectRoot, 'Src'))
        parentDir = fileparts(projectRoot);
        if isempty(parentDir) || strcmp(parentDir, projectRoot); projectRoot = thisDir; break; end
        projectRoot = parentDir;
    end
    xlsxFile = fullfile(projectRoot, 'Data', 'CORS_coordinate_최종본.xlsx');
    if ~isfile(xlsxFile)
        error('load_cors_external: 파일이 없습니다: %s', xlsxFile);
    end

    Raw = readtable(xlsxFile, 'Sheet', 'OBS_HEADER', 'VariableNamingRule', 'preserve');
    [lat, lon, hEll] = ecef2geodetic(referenceEllipsoid('GRS80'), Raw.X, Raw.Y, Raw.Z);

    % 데이터 이상 처리 (2026-07 최종본 기준 실측 확인):
    %  - GAGE(가거도)·HGDO(홍도): 고시 XYZ 손상(|h|>700 km) → xlsx 참고 Lat/Lon/Height 로 대체
    %  - DAGR·DJKD·GANG: XYZ 는 정상, xlsx 참고 Lat/Lon 열이 손상 → 변환값 사용 (자동)
    badXYZ = abs(hEll) > 1e4 | lat < 20 | lat > 45 | lon < 110 | lon > 140;
    useRef = badXYZ & ~isnan(Raw.Lat) & ~isnan(Raw.Lon);
    lat(useRef)  = Raw.Lat(useRef);
    lon(useRef)  = Raw.Lon(useRef);
    hEll(useRef) = Raw.Height(useRef);
    src = repmat("xyz", height(Raw), 1);
    src(useRef) = "xlsx_llh";
    if any(badXYZ & ~useRef)
        warning('load_cors_external: XYZ 손상인데 참고열도 없어 좌표가 비정상인 국: %s', ...
            strjoin(string(Raw.station(badXYZ & ~useRef)), ', '));
    end

    T = table(string(Raw.station), string(Raw.mngr_nm), string(Raw.status), ...
              lat, lon, hEll, src, ...
              'VariableNames', {'station','agency','status','lat','lon','hEll','src'});
end
