
function filelist=getLiveImages()
    timeOfDay = getTimeOfDay();
    plates = ["T67YVU", "V01KHQ", "WTG38N"];
    imgDir = strcat('images/problem1-1/', timeOfDay, '/', datestr(now, 'HHMM'));

    for camId = 1:3
        camIdStr = num2str(camId);
        camera = ipcam(['http://10.112.11.21' camIdStr '/video.mjpg'], 'root', ['Vivotek' camIdStr]);
        image = snapshot(camera);
        %figure, imshow(image);
        
        if ~exist(imgDir, 'dir')
            mkdir(imgDir);
        end
        
        imwrite(image, strcat(imgDir, '/', plates(:, camId), '.png'))
        filelist(camId) = dir(strcat(imgDir, '/', plates(:, camId), '.png'));
    end
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