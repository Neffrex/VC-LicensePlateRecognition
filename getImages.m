timeOfDay = getTimeOfDay();
plates = ["T67YVU", "V01KHQ", "WTG38N"];

for camId = 1:3
    camIdStr = num2str(camId);
    camera = ipcam(strcat('http://10.112.11.21',camIdStr,'/video.mjpg'), 'root', strcat('Vivotek',camIdStr));
    image = snapshot(camera);
    figure, imshow(image);

    imgDir = strcat('images/',timeOfDay,'/',plates(:, camId));
    if ~exist(imgDir, 'dir')
        mkdir(imgDir);
    end

    imwrite(image, strcat(imgDir+'/'+datestr(now, 'HHMM')+'.png'))
end

function s = getTimeOfDay()
    h = hour(datetime('now'));
    if h < 12
        s = "morning";
    elseif h < 18
        s = "afternoon";
    else
        s = "evening";
    end
end