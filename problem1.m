
ex1("other", 1)

function []=ex1(mode, difficulty)

    if(strcmp(mode, "live"))
        cam1 = ipcam('http://10.112.11.211/video.mjpg', 'root', 'Vivotek1', 'Timeout', 10);
        cam2 = ipcam('http://10.112.11.212/video.mjpg', 'root', 'Vivotek2', 'Timeout', 10);
        cam3 = ipcam('http://10.112.11.213/video.mjpg', 'root', 'Vivotek3', 'Timeout', 10);
        
        filelist = [ snapshot(cam1) snapshot(cam2) snapshot(cam3)];
    else
        filelist = dir(fullfile('images/problem1.1', '**\*.*'));
        filelist = filelist(~[filelist.isdir]);  % Borrar directorios
    end
    
    %% 1. Lectura y preprocesado de la imagen
    for i = 1:length(filelist)
        file = filelist(i);
        im = imread(fullfile(file.folder, file.name));
        %figure('Name', 'Imagen original'), imshow(im);
        
        %% 2. Detección de la region de la matricula
        imPlate = detectPlateRegionCE(im);
          
        %% 3. Extraer caracteres
        charList = segmentCharacters(imPlate);
    
        %% 4. Identificar caracteres
        templates = loadTemplates('templates/problem1');
        
        plate = length(charList);
        recognisedCharacters = 0;
        for j = 1:length(charList)
            plate(j) = matchCharacter(charList{j}, templates);
            if(plate(j) == file.name(j))
                recognisedCharacters = recognisedCharacters + 1;
            end
        end
        
        disp([fullfile(file.folder, file.name) ':'])
        disp([9 'Detected Plate: ' plate ' | Ground Truth: ' file.name ' | Recognised Characters ' num2str(recognisedCharacters)])
    
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
    %figure('Name', 'Imagen recortada'), imshow(imPlate);
end

function templates = loadTemplates(templateDir)
    % Carregar imatges de referència (0-9, A-Z) des de carpeta 'templates'
    symbols = ['0':'9' 'A':'Z'];
    maxSymbols = numel(symbols);
    j = 1;
    for i = 1:maxSymbols
        character = symbols(i);
        imgPath = fullfile(templateDir, [character '.png']);
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