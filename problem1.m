
ex1(1, "other")

function []=ex1(difficulty, mode)
    filelist = loadFiles(difficulty, mode);
    templates = loadTemplates(difficulty);

    for i = 1:length(filelist)
        %% 1. Lectura de la imagen
        file = filelist(i);
        im = imread(fullfile(file.folder, file.name));
        %figure('Name', 'Imagen original'), imshow(im);
        
        %% 2. Detección de la region de la matricula
        imPlate = detectPlateRegionCE(im);
        %figure('Name', 'Placa recortada'), imshow(imPlate);
        
        %% 3. Extraer caracteres
        charList = segmentCharacters(imPlate);
    
        %% 4. Identificar caracteres
        [plate, numValids] = recogniseCharacters(charList, file.name(1:6), templates);
        
        %% 5. Informar de los resultados
        disp([fullfile(file.folder, file.name) ':']);
        disp([9 'Detected Plate: ' plate ' | Ground Truth: ' file.name(1:6) ' | Recognised Characters ' num2str(numValids)]);
    end
    
end

function filelist = loadFiles(difficulty, mode)
    if(difficulty == 1)
        % Entorno controlado
        if(strcmp(mode, "live"))
            cam1 = ipcam('http://10.112.11.211/video.mjpg', 'root', 'Vivotek1', 'Timeout', 10);
            cam2 = ipcam('http://10.112.11.212/video.mjpg', 'root', 'Vivotek2', 'Timeout', 10);
            cam3 = ipcam('http://10.112.11.213/video.mjpg', 'root', 'Vivotek3', 'Timeout', 10);
            
            filelist = [ snapshot(cam1) snapshot(cam2) snapshot(cam3)];
        else
            filelist = dir(fullfile('images/problem1.1', '**\*.*'));
            filelist = filelist(~[filelist.isdir]);
        end
    else
        % Caso real
        filelist = dir(fullfile('images/problem1.2', '**\*.*'));
        filelist = filelist(~[filelist.isdir]);
    end
end

function imPlate = detectPlateRegionCE(im)
    %% 1. Aplicar filtro de color

    % Convertir a espacio HSV para facilitar filtrado de color verde
    imHSV = rgb2hsv(im);
    h = imHSV(:,:,1);  % canal Hue
    s = imHSV(:,:,2);  % canal Saturation
    v = imHSV(:,:,3);  % canal Value
    
    % Definir filtro de color (verde -> entorno controlado, blanco -> escenario)
    hMin = 118/360; hMax = 183/360;
    sMin =  80/255; sMax = 255/255;
    vMin =  53/255; vMax = 175/255;

    % Aplicar la mascara
    imMasked = (h>=hMin & h<=hMax) & (s>=sMin & s<=sMax) & (v>=vMin & v<=vMax);
    %figure('Name', 'Máscara de verdes'), imshow(imMasked);
    
    %% 2. Eliminar artefactos pequeños
    imClean = bwpropfilt(imMasked, 'Area', 6); 
    %figure('Name', 'Imagen limpia'), imshow(imClean);

    %% 3. Recortar la matricula
    [rows, cols] = find(imClean);
    
    % Definir los limites
    rMin = min(rows); rMax = max(rows);
    cMin = min(cols); cMax = max(cols);
    
    % Recortado
    imPlate = imClean(rMin:rMax, cMin:cMax, :);
end

function templates = loadTemplates(difficulty)
    % Carregar imatges de referència (0-9, A-Z) des de carpeta 'templates'
    symbols = ['0':'9' 'A':'Z'];
    maxSymbols = numel(symbols);
    j = 1;
    for i = 1:maxSymbols
        character = symbols(i);
        imgPath = fullfile(['templates/problem1.' num2str(difficulty)], [character '.png']);
        if isfile(imgPath)
            templates.symbols{j} = character;
            templates.images{j}  = im2bw(imresize(imread(imgPath),[42 24]));
            j = j + 1;
        end
        
    end
end

function bestChar = matchCharacter(charImg, templates)
    % Compara charImg amb totes les plantilles i retorna la millor coincidència
    bestScore = Inf;
    bestChar  = '?';
    for k = 1:length(templates.images)
        tmpl = templates.images{k};
        score = sum((double(charImg(:)) - double(tmpl(:))).^2);
        if score < bestScore
            bestScore = score;
            bestChar = templates.symbols{k};
        end
    end
end

function charList = segmentCharacters(imPlate)
    cc = bwconncomp(imPlate);
    Iprops = regionprops(cc, 'BoundingBox', 'Area');
    count = numel(Iprops);
    charList = cell(1, count);
    for i=1:count
      boundingBox = Iprops(i).BoundingBox;
      imChar = imcrop(imPlate, boundingBox);
      charList{i} = imresize(imChar,[42 24]);
      %figure; imshow(imChar);
    end
end


function [plate, nValids] = recogniseCharacters(charList, groundTruth, templates)
    plate = length(charList);
    nValids = 0;
    for j = 1:length(charList)
        plate(j) = matchCharacter(charList{j}, templates);
        if(plate(j) == groundTruth(j))
            nValids = nValids + 1;
        end
    end
end