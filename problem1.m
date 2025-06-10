function [] = problem1()
    % Carga la lista de ficheros de imágenes y las plantillas de caracteres
    filelist  = loadFiles();
    templates = loadTemplates();

    for i = 1:length(filelist)
        %% 1. Lectura de la imagen
        file = filelist(i);
        im   = imread(fullfile(file.folder, file.name));
        
        %% 2. Detección de la región de la matrícula
        % Devuelve la placa recortada y las imágenes en cada fase
        [imPlate, imOriginal, imMasked, imClean] = detectPlateRegion(im);
        
        %% 3. Segmentación de caracteres
        charList = segmentCharacters(imPlate);
    
        %% 4. Reconocimiento de caracteres
        [plate, numValids] = recogniseCharacters(charList, file.name(1:6), templates);
        
        %% 5. Informe de resultados y guardado de imágenes
        fprintf('%s:\n\tDetected Plate: %s | Ground Truth: %s | Recognised: %d/%d\n', ...
                fullfile(file.folder, file.name), plate, file.name(1:6), numValids, length(plate));
        
        % Crear carpeta de salida según la franja horaria
        if(~isempty(plate))
            [~, time, ~] = fileparts(file.folder);
            outputDir = fullfile('figures', time);
            if ~exist(outputDir, 'dir')
                mkdir(outputDir);
            end
            
            % Guardar cada fase del procesamiento para análisis
            imwrite(imOriginal, fullfile(outputDir, [file.name '-Original.png']));
            imwrite(imMasked,   fullfile(outputDir, [file.name '-Masked.png']));
            imwrite(imClean,    fullfile(outputDir, [file.name '-Clean.png']));
            imwrite(imPlate,    fullfile(outputDir, [file.name '-Plate.png']));
            imwrite([charList{:}], fullfile(outputDir, [file.name '-Segmentation.png']));
        end
    end
end

function filelist = loadFiles()
    % Obtiene todos los archivos dentro de images/problem1-1 (subcarpetas incl.)
    filelist = dir(fullfile('images/problem1-1', '**', '*.*'));
    filelist = filelist(~[filelist.isdir]);  % Filtrar directorios
end

function [imPlate, imOriginal, imMasked, imClean] = detectPlateRegion(imOriginal)
    %% 1. Filtrado de color en HSV para aislar la cartulina
    imMasked = colorFilter(imOriginal, [60/360 180/360], [0.3 1], [0.2 0.68]);
    
    %% 2. Eliminar componentes muy pequeños (ruido)
    imClean = bwpropfilt(imMasked, 'Area', 6);
    
    %% 3. Recorte exacto de la placa usando bounding box
    [rows, cols] = find(imClean);
    rMin = min(rows); rMax = max(rows);
    cMin = min(cols); cMax = max(cols);
    imPlate = imClean(rMin:rMax, cMin:cMax);
end

function templates = loadTemplates()
    % Carga plantillas binarias (0-9, A-Z) redimensionadas a 42×24 px
    symbols    = ['0':'9' 'A':'Z'];
    templates.symbols = {};
    templates.images  = {};
    j = 1;
    for i = 1:length(symbols)
        imgPath = fullfile('templates/problem1-1', [symbols(i) '.png']);
        if isfile(imgPath)
            templates.symbols{j} = symbols(i);
            % Leer, binarizar y ajustar tamaño
            tpl = imresize(imread(imgPath), [42 24]);
            templates.images{j} = imbinarize(rgb2gray(tpl));
            j = j + 1;
        end
    end
end

function bestChar = matchCharacter(charImg, templates)
    % Compara un carácter con cada plantilla, eligiendo la de menor error
    bestScore = Inf;
    bestChar  = '?';
    for k = 1:length(templates.images)
        diff  = double(charImg(:)) - double(templates.images{k}(:));
        score = sum(diff .^ 2);
        if score < bestScore
            bestScore = score;
            bestChar  = templates.symbols{k};
        end
    end
end

function charList = segmentCharacters(imPlate)
    % Segmenta cada carácter mediante componentes conexos
    cc     = bwconncomp(imPlate);
    props  = regionprops(cc, 'BoundingBox');
    charList = cell(1, numel(props));
    % Ordenar por posición horizontal (x) para mantener el orden de lectura
    bboxes = reshape([props.BoundingBox], 4, [])';
    [~, idx] = sort(bboxes(:,1));
    for i = 1:length(idx)
        bb = props(idx(i)).BoundingBox;
        imChar = imcrop(imPlate, bb);
        % Redimensionar a tamaño fijo para el matching
        charList{i} = imresize(imChar, [42 24]);
    end
end

function [plate, nValids] = recogniseCharacters(charList, groundTruth, templates)
    % Reconoce cada carácter y cuenta los aciertos
    plate   = repmat('?', 1, length(charList));
    nValids = 0;
    for j = 1:length(charList)
        plate(j) = matchCharacter(charList{j}, templates);
        if plate(j) == groundTruth(j)
            nValids = nValids + 1;
        end
    end
end

function imMasked = colorFilter(im, hRange, sRange, vRange)
    % Filtrado en espacio HSV según rangos de H, S y V
    hsv     = rgb2hsv(im);
    h = hsv(:,:,1); s = hsv(:,:,2); v = hsv(:,:,3);
    imMasked = (h >= hRange(1) & h <= hRange(2)) & ...
               (s >= sRange(1) & s <= sRange(2)) & ...
               (v >= vRange(1) & v <= vRange(2));
end
