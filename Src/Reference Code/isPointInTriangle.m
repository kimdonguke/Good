function inside = isPointInTriangle(px, py, x1, y1, x2, y2, x3, y3)
    % 삼각형의 꼭짓점 좌표: (x1, y1), (x2, y2), (x3, y3)
    % 검사할 점: (px, py)
    
    % 벡터 계산
    v0 = [x3 - x1, y3 - y1]; 
    v1 = [x2 - x1, y2 - y1]; 
    v2 = [px - x1, py - y1]; 
    
    % Barycentric 좌표 계산
    dot00 = dot(v0, v0);
    dot01 = dot(v0, v1);
    dot02 = dot(v0, v2);
    dot11 = dot(v1, v1);
    dot12 = dot(v1, v2);
    
    denom = dot00 * dot11 - dot01 * dot01;
    
    % u, v 값 계산
    u = (dot11 * dot02 - dot01 * dot12) / denom;
    v = (dot00 * dot12 - dot01 * dot02) / denom;
    
    % 점이 삼각형 내부에 있는지 확인 (u, v가 0~1 사이이고 u+v가 1 이하)
    inside = (u >= 0) && (v >= 0) && (u + v <= 1);
end
