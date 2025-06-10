ex1(2, true)

function []=ex1(difficulty, live)
    filelist = loadFiles(difficulty, live);

    for i = 1:length(filelist)
        file = filelist(i);
        if(difficulty == 1)
            processFileControlledEnvironment(file);
        else
            processFileRealEnvironment(file);
        end
    end
    
end

function processFileControlledEnvironment(file)
    %% 1. Lectura de la imagen
    im = imread(fullfile(file.folder, file.name));
    %figure('Name', 'Imagen original'), imshow(im);
    
    %% 2. Detección de la region de la matricula
    imPlate = detectPlateRegionCE(im);
    %figure('Name', 'Placa recortada'), imshow(imPlate);
    
    %% 3. Extraer caracteres
    charList = segmentCharacters(imPlate);

    %% 4. Identificar caracteres
    [plate, nValids] = recogniseCharactersCE(charList, file.name(1:6));
    
    %% 5. Informar de los resultados
    disp([fullfile(file.folder, file.name) ':']);
    disp([9 'Detected Plate: ' plate ' | Ground Truth: ' file.name(1:6) ' | Recognised Characters ' num2str(nValids)]);
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

function imPlate = processFileRealEnvironment(file)
    im = imread(fullfile(file.folder, file.name));

     % Convertir a espacio HSV para facilitar filtrado de color verde
    imMasked = colorFilter(im, [0 360], [0 .1], [.9 1]);
    %showImage('Filtro de blancos', imMasked);

    imEdges = edge(rgb2gray(im), "canny");
    %showImage('Imagen de contornos', imEdges);

    plateBB = greaterBoundingBox(regionprops(imMasked, 'BoundingBox', 'Area'));
    imDirty = imcrop(imEdges, plateBB);
    %showImage('Placa sucia', imDirty);

    imFilled = imfill(imDirty, "holes");
    %showImage('Placa rellena', imFilled);

    imClean = bwpropfilt(imFilled, 'Area', 8); 
    %showImage('Placa limpia', imClean);

    imPlate = imDirty & imClean;
    %showImage('Placa arreglada', imPlate);
    

    [h, ~] = size(imClean);

    stats = regionprops(imClean, 'BoundingBox', 'Area', 'Image');
    j = 1;
    for i=1:numel(stats)
        subImWidth  = length(stats(i).Image(1,:));
        subImHeight = length(stats(i).Image(:,1));
        if subImWidth<(h/2) & subImHeight>(h/3)
            imChar = imcrop(imPlate, stats(i).BoundingBox);
            charList{j} = imresize(imChar,[42 24]);
            
            [name, figure] = showImage([file.name(1:6) '-' num2str(j)], charList{j});
            saveas(figure, ['figures/' name '.png']);
            j = j + 1;
        end
    end
    
    [plate, nValids] = recogniseCharactersRE(charList, file.name(1:6));
    
    disp([fullfile(file.folder, file.name) ':']);
    disp([9 'Detected Plate: ' plate ' | Ground Truth: ' file.name(1:6) ' | Recognised Characters ' num2str(nValids)]);
end

function templates = loadTemplates(path)
    % Carregar imatges de referència (0-9, A-Z) des de carpeta 'templates'
    symbols = ['0':'9' 'A':'Z'];
    maxSymbols = numel(symbols);
    j = 1;
    for i = 1:maxSymbols
        character = symbols(i);
        imgPath = fullfile(path, [character '.png']);
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


function charList = segmentCharactersCE(imPlate)
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


function [plate, nValids] = recogniseCharactersCE(charList, groundTruth)
    loadTemplates('templates/problem1-1')
    plate = length(charList);
    nValids = 0;
    for j = 1:length(charList)
        plate(j) = matchCharacter(charList{j}, templates);
        if(plate(j) == groundTruth(j))
            nValids = nValids + 1;
        end
    end
end

function [plate, nValids] = recogniseCharactersRE(charList, groundTruth)
    numberTemplates = loadTemplates('templates/problem1-2/numbers');
    alphaTemplates  = loadTemplates('templates/problem1-2/alpha');

    plateLength = length(charList);
    nValids = 0;
    for j = 1:plateLength
        if(j <= plateLength/2)
            template = numberTemplates;
        else
            template = alphaTemplates;
        end
        
        plate(j) = matchCharacter(charList{j}, template);
        if(plate(j) == groundTruth(j))
            nValids = nValids + 1;
        end
    end
end

function imMasked = colorFilter(im, hRange, sRange, vRange)
    imHSV = rgb2hsv(im);
    h = imHSV(:,:,1);  % canal Hue
    s = imHSV(:,:,2);  % canal Saturation
    v = imHSV(:,:,3);  % canal Value

    % Aplicar la mascara
    imMasked = (hRange(1)<=h & h<=hRange(2)) & (sRange(1)<=s & s<=sRange(2)) & (vRange(1)<=v & v<=vRange(2));

end


function bb = greaterBoundingBox(stats)
    bb = stats(1).BoundingBox;
    maxArea = 0;
    count=numel(stats);
    for i=1:count
        boundingBox = stats(i).BoundingBox;
        area = stats(i).Area;
        if maxArea < area
           maxArea = area;
           bb = boundingBox;
        end
    end
end


function [name, fig]=showImage(name, im)
    fig = figure('Name', name);
    imshow(im);
end