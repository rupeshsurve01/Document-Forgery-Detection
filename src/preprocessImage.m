
function grayImg = preprocessImage(img)
% Convert RGB image to grayscale
if size(img, 3) == 3
    grayImg = rgb2gray(img);
else
    grayImg = img;
end

% Convert to uint8 format
grayImg = im2uint8(grayImg);

% Reduce small amounts of noise
grayImg = medfilt2(grayImg, [3 3]);
end
