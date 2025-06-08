ex1(2, true)

function []=ex1(difficulty, live)
    filelist = loadFiles(difficulty, live);
    templates = loadTemplates(difficulty);

    for i = 1:length(filelist)
        %% 1. Lectura de la imagen
        file = filelist(i);
        im = imread(fullfile(file.folder, file.name));
        %figure('Name', 'Imagen original'), imshow(im);
        
        %% 2. Detección de la region de la matricula
        imPlate = detectPlateRegion(im, difficulty);
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

function filelist = loadFiles(difficulty, live)
    if(difficulty == 1)
        % Entorno controlado
        if(live)
            filelist = getLiveImages();
        else
            filelist = dir(fullfile('images/problem1-1', '**\*.*'));
            filelist = filelist(~[filelist.isdir]);
        end
    else
        % Caso real
        filelist = dir(fullfile('images/problem1-2', '**\*.*'));
        filelist = filelist(~[filelist.isdir]);
    end
end


function imPlate = detectPlateRegion(im, difficulty)
    if(difficulty == 1)
        % Controlled Environment (CE)
        imPlate = detectPlateRegionCE(im);
    else 
        % Real Environment (RE)
        imPlate = detectPlateRegionRE(im);
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
    hMin = 91/360; hMax = 183/360;
    sMin = 80/255; sMax = 255/255;
    vMin = 53/255; vMax = 175/255;

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

function imPlate = detectPlateRegionRE(im)
    % 1) Conversión a gris y filtrado suave
    imGray = rgb2gray(im);
    imGray = medfilt2(imGray, [3 3]);
    
    % 2) Detección de bordes más precisa con Canny
    edges = edge(imGray, 'Canny', [0.05 0.15]);
    
    %% 1. Aplicar operaciones morfologicas
    imGray = rgb2gray(im);
    imGray = medfilt2(imGray, [3 3]);
    %figure('Name', 'Imagen de grises'); imshow(imGray);

    % Apply morphological operations to enhance the detected edges
    se = strel('disk', 1);
    imDilated = imdilate(imGray, se);
    imEroded = imerode(imGray, se);
    imClean = imsubtract(imDilated, imEroded);
    imClean = mat2gray(imClean);
    figure('Name', 'Imagen limpia'); imshow(imClean);

    imClean = imadjust(imClean, [0.2 .7], [0 1]);
    imClean = bwpropfilt(logical(imClean), 'Area', 20); 
    figure('Name', 'Imagen limpia'); imshow(imClean);
    
    %imClean = conv2(imClean, [1 1; 1 1], "same");
    %imClean = imadjust(imClean, [0.7 1], [0 1]);
    %imClean = bwpropfilt(logical(imClean), 'Area', 15); 
    %figure('Name', 'Imagen limpia'); imshow(imClean);
    
    %% 2. Recortar la matricula
    cc = bwconncomp(imClean);
    Iprops = regionprops(cc, 'BoundingBox', 'Area');
    
    bb = Iprops(1).BoundingBox;
    maxArea = 0;
    for i=1:numel(Iprops)
        boundingBox = Iprops(i).BoundingBox;
        area = Iprops(i).Area;
        aspectRatio = boundingBox(3) / boundingBox(4);
        if maxArea < area && aspectRatio > 1.7 && aspectRatio < 2
           maxArea = area;
           bb = boundingBox;
           figure('Name', num2str(area)); imshow(imcrop(imClean, bb));
        end
    end
    
    imPlate = imcrop(imClean, bb);
    imPlate = bwareaopen(~imPlate, 500);
    [h, ~] = size(imPlate);

    Iprops=regionprops(imClean,'BoundingBox', 'Area', 'Image');
    count = numel(Iprops);
    %noPlate=[];
    for i=1:count
        ow = length(Iprops(i).Image(1,:));
        oh = length(Iprops(i).Image(:,1));
        if ow<(h/2) & oh>(h/3)
            figure('Name', ['Letter' i]); imshow(Iprops(i).Image);
        end
    end

    pause
end

function templates = loadTemplates(difficulty)
    % Carregar imatges de referència (0-9, A-Z) des de carpeta 'templates'
    symbols = ['0':'9' 'A':'Z'];
    maxSymbols = numel(symbols);
    j = 1;
    for i = 1:maxSymbols
        character = symbols(i);
        imgPath = fullfile(['templates/problem1-' num2str(difficulty)], [character '.png']);
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