function [resultImg, matchedPoints1, matchedPoints2] = detectCopyMove(img)

    disp('Starting RANSAC-verified single-image copy-move detection...');

    if nargin < 1 || isempty(img)
        error('Input image is required. Example: detectCopyMove(img)');
    end

    resultImg = img;
    if size(img,3) == 3
        gray = rgb2gray(img);
    else
        gray = img;
    end
    gray = im2uint8(gray);
    [H,W] = size(gray);

    matchedPoints1 = zeros(0,2);
    matchedPoints2 = zeros(0,2);

    %% 1. Split image into overlapping tiles
    tileW = ceil(W/2);
    tileH = ceil(H/2);
    starts = [1 1; max(1,floor(W/2)) 1; ...
              1 max(1,floor(H/2)); max(1,floor(W/2)) max(1,floor(H/2))];

    tiles = cell(4,1);
    offsets = zeros(4,2); % [x y] offset to full-image coordinates
    for t = 1:4
        x0 = starts(t,1);
        y0 = starts(t,2);
        x1 = min(W,x0+tileW-1);
        y1 = min(H,y0+tileH-1);
        tiles{t} = gray(y0:y1,x0:x1);
        offsets(t,:) = [x0-1 y0-1];
    end

    %% 2. Detect and match SURF features across tile pairs
    tilePairs = nchoosek(1:4,2);
    for k = 1:size(tilePairs,1)
        a = tilePairs(k,1);
        b = tilePairs(k,2);

        pointsA = detectSURFFeatures(tiles{a},'MetricThreshold',150);
        pointsB = detectSURFFeatures(tiles{b},'MetricThreshold',150);
        if pointsA.Count < 4 || pointsB.Count < 4
            continue;
        end

        [featuresA,validA] = extractFeatures(tiles{a},pointsA);
        [featuresB,validB] = extractFeatures(tiles{b},pointsB);
        pairs = matchFeatures(featuresA,featuresB, ...
            'Unique',true,'MaxRatio',0.65,'MatchThreshold',60);
        if isempty(pairs)
            continue;
        end

        pA = validA(pairs(:,1)).Location + offsets(a,:);
        pB = validB(pairs(:,2)).Location + offsets(b,:);

        % Reject near-identical points and implausibly short shifts.
        delta = pB-pA;
        keep = hypot(delta(:,1),delta(:,2)) > 35;
        matchedPoints1 = [matchedPoints1; pA(keep,:)]; %#ok<AGROW>
        matchedPoints2 = [matchedPoints2; pB(keep,:)]; %#ok<AGROW>
    end

    %% 3. Remove duplicate matches caused by overlapping tiles
    if ~isempty(matchedPoints1)
        pairTable = round([matchedPoints1 matchedPoints2]);
        [~,uniqueIdx] = unique(pairTable,'rows','stable');
        matchedPoints1 = matchedPoints1(uniqueIdx,:);
        matchedPoints2 = matchedPoints2(uniqueIdx,:);
    end

    n = size(matchedPoints1,1);
    fprintf('Unique candidate feature pairs: %d\n',n);
    if n < 8
        warning('Too few feature pairs. Try a sharper, higher-resolution image.');
        return;
    end

    allP1 = matchedPoints1;
    allP2 = matchedPoints2;
    displacement = allP2-allP1;

    %% 4. Cluster displacement vectors
    epsShift = 12; 
    minShiftPoints = max(6,ceil(0.015*n));
    labels = dbscan(displacement,epsShift,minShiftPoints);
    clusterIds = unique(labels(labels > 0));

    if isempty(clusterIds)
        warning('No consistent displacement cluster was found.');
        showCandidateDisplacements(displacement,labels);
        return;
    end

    counts = arrayfun(@(id) sum(labels==id),clusterIds);
    [~,order] = sort(counts,'descend');

    %% 5. Apply RANSAC geometric verification to strongest clusters

    selected = false(n,1);
    chosenId = NaN;
    selectedTransform = [];
    selectedShift = [NaN NaN];

    for j = 1:numel(order)
        id = clusterIds(order(j));
        candidate = labels == id;
        if sum(candidate) < max(6,minShiftPoints)
            continue;
        end

        src = allP1(candidate,:);
        dst = allP2(candidate,:);
        if spatialSpread(src) < 25 || spatialSpread(dst) < 25
            continue;
        end

        try
            srcObj = cornerPoints(src);
            dstObj = cornerPoints(dst);
            [tform,inlierIdx] = estimateGeometricTransform2D( ...
                srcObj,dstObj,'similarity', ...
                'MaxDistance',4,'Confidence',99,'MaxNumTrials',3000);
            inlierIdx = logical(inlierIdx(:));
        catch ME
            warning('RANSAC verification failed for a cluster: %s',ME.message);
            continue;
        end

        if numel(inlierIdx) ~= size(src,1) || sum(inlierIdx) < 6
            continue;
        end

        inSrc = src(inlierIdx,:);
        inDst = dst(inlierIdx,:);
        inShift = inDst-inSrc;
        medShift = median(inShift,1);
        residual = hypot(inShift(:,1)-medShift(1), ...
                         inShift(:,2)-medShift(2));

        % Keep mostly translational matches; reject large geometric spread.
        if median(residual) > 5 || spatialSpread(inSrc) < 25 || spatialSpread(inDst) < 25
            continue;
        end

        candidateIndices = find(candidate);
        selected(candidateIndices(inlierIdx)) = true;
        chosenId = id;
        selectedTransform = tform;
        selectedShift = medShift;
        break;
    end

    if ~any(selected)
        warning(['No displacement cluster passed RANSAC and translation ' ...
                 'checks. The repeated document layout may be causing false matches.']);
        showCandidateDisplacements(displacement,labels);
        return;
    end

    %% 6. Keep only verified inlier point pairs
    src = allP1(selected,:);
    dst = allP2(selected,:);
    shift = median(dst-src,1);

    fprintf('Displacement clusters found: %d\n',numel(clusterIds));
    fprintf('Selected cluster: %d\n',chosenId);
    fprintf('RANSAC-verified inlier pairs: %d of %d candidates\n',size(src,1),n);
    fprintf('Median translation: dx = %.1f px, dy = %.1f px\n',shift(1),shift(2));

    matchedPoints1 = src;
    matchedPoints2 = dst;

    %% Figure 2: displacement consensus
    figure('Name','Copy-Move Displacement Consensus','Color','w');
    scatter(displacement(:,1),displacement(:,2),10,[0.65 0.65 0.65],'filled');
    hold on;
    scatter(displacement(selected,1),displacement(selected,2),24,'filled');
    xlabel('Horizontal displacement (pixels)');
    ylabel('Vertical displacement (pixels)');
    title(sprintf('RANSAC-Verified Translation: (%.1f, %.1f) px',shift(1),shift(2)));
    legend('Other candidates','Verified inliers','Location','best');
    grid on;
    hold off;

    %% Figure 3: selected verified matches
    figure('Name','Selected Copy-Move Feature Matches','Color','w');
    showMatchedFeatures(gray,gray,src,dst,'montage');
    title(sprintf('RANSAC-Verified Candidate Matches (%d pairs)',size(src,1)));

    %% Figure 4: candidate point locations
    figure('Name','Copy-Move Candidate Locations','Color','w');
    imshow(img);
    hold on;
    plot(src(:,1),src(:,2),'ro','MarkerSize',4,'LineWidth',1);
    plot(dst(:,1),dst(:,2),'g+','MarkerSize',5,'LineWidth',1);
    title('Verified Candidate Source (red) and Destination (green) Points');
    legend('Source candidates','Destination candidates','Location','best');
    hold off;

    %% Figure 5: spatially clustered candidate boxes
    srcBoxes = pointCloudBoxes(src,W,H);
    dstBoxes = pointCloudBoxes(dst,W,H);

    figure('Name','Refined Copy-Move Candidate Regions','Color','w');
    imshow(img);
    hold on;
    for q = 1:size(srcBoxes,1)
        rectangle('Position',srcBoxes(q,:),'EdgeColor','r','LineWidth',2);
    end
    for q = 1:size(dstBoxes,1)
        rectangle('Position',dstBoxes(q,:),'EdgeColor','g','LineWidth',2);
    end
    title('RANSAC-Verified Candidate Regions: Red = Source, Green = Destination');
    hold off;

    disp('Analysis completed. Inspect the highlighted regions manually.');
    disp('RANSAC reduces inconsistent matches but cannot eliminate all false positives.');
end

function spread = spatialSpread(points)
    if size(points,1) < 3
        spread = 0;
        return;
    end
    spread = max([range(points(:,1)),range(points(:,2))]);
end

function boxes = pointCloudBoxes(points,W,H)
% Find spatial groups among verified source or destination points.
    boxes = zeros(0,4);
    if size(points,1) < 5
        return;
    end

    labels = dbscan(points,35,5);
    ids = unique(labels(labels > 0));
    for i = 1:numel(ids)
        p = points(labels == ids(i),:);
        if size(p,1) < 5
            continue;
        end
        pad = 18;
        x1 = max(1,floor(min(p(:,1))-pad));
        y1 = max(1,floor(min(p(:,2))-pad));
        x2 = min(W,ceil(max(p(:,1))+pad));
        y2 = min(H,ceil(max(p(:,2))+pad));
        if x2 > x1 && y2 > y1
            boxes(end+1,:) = [x1 y1 x2-x1 y2-y1]; %#ok<AGROW>
        end
    end

    if isempty(boxes)
        pad = 18;
        x1 = max(1,floor(min(points(:,1))-pad));
        y1 = max(1,floor(min(points(:,2))-pad));
        x2 = min(W,ceil(max(points(:,1))+pad));
        y2 = min(H,ceil(max(points(:,2))+pad));
        boxes = [x1 y1 max(1,x2-x1) max(1,y2-y1)];
    end
end

function showCandidateDisplacements(displacement,labels)
    figure('Name','Copy-Move Displacements - No Reliable Cluster','Color','w');
    gscatter(displacement(:,1),displacement(:,2),labels);
    xlabel('Horizontal displacement (pixels)');
    ylabel('Vertical displacement (pixels)');
    title('Candidate Displacements - No Reliable Cluster Selected');
    grid on;
end
