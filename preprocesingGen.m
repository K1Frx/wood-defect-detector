% preprocess_wood_defects_FINAL.m
% OSTATECZNA wersja - 3 grupy defektów z różnymi kolorami
% KNOT (czerwony), RESIN (zielony), CRACK (niebieski)

% ============== KONFIGURACJA ==============
srcImgDir  = fullfile('dataset','img');
srcAnnDir  = fullfile('dataset','ann');
outDir     = fullfile('dataset_preprocessed');
outImgDir  = fullfile(outDir,'img');
outAnnDir  = fullfile(outDir,'ann');

doHistEq   = true;
normalize  = true;

% NOWA STRUKTURA - 3 grupy
knotClasses = {'Live_knot', 'Death_know', 'knot_with_crack', 'Knot_missing'};
resinClasses = {'resin'};
crackClasses = {'Crack'};

% Wszystkie klasy do przetwarzania
allTargetClasses = [knotClasses, resinClasses, crackClasses];

% Mapowanie klasy → wartość w masce (1=KNOT, 2=RESIN, 3=CRACK)
classToValue = containers.Map();
for i = 1:length(knotClasses)
    classToValue(knotClasses{i}) = 1;  % KNOT = 1 (czerwony)
end
for i = 1:length(resinClasses)
    classToValue(resinClasses{i}) = 2;  % RESIN = 2 (zielony)
end
for i = 1:length(crackClasses)
    classToValue(crackClasses{i}) = 3;  % CRACK = 3 (niebieski)
end

fprintf('🎯 GRUPY DEFEKTÓW:\n');
fprintf('   🔴 KNOT: %s\n', strjoin(knotClasses, ', '));
fprintf('   🟢 RESIN: %s\n', strjoin(resinClasses, ', '));
fprintf('   🔵 CRACK: %s\n', strjoin(crackClasses, ', '));
fprintf('\n');

% Tworzenie folderów
if ~exist(outImgDir,'dir'), mkdir(outImgDir); end
if ~exist(outAnnDir,'dir'), mkdir(outAnnDir); end

% ============== LISTA OBRAZÓW ==============
imgFiles = dir(fullfile(srcImgDir,'*.bmp'));

if isempty(imgFiles)
    error('❌ Brak plików BMP w: %s', srcImgDir);
end

fprintf('Znaleziono %d obrazów\n\n', numel(imgFiles));

% Inicjalizacja
masksAll = {};
labelsAll = {};
imgPaths = {};
imgSizes = [];

% Statystyki dla 3 grup
groupStats = containers.Map({'KNOT', 'RESIN', 'CRACK'}, [0, 0, 0]);
allFoundClasses = {};

% ============== FUNKCJA: DEKOMPRESJA PRZEZ PYTHON ==============
function mask = decodeSupervisellyBitmap(base64Data)
    % Dekoduj base64
    binaryData = matlab.net.base64decode(base64Data);
    
    % Zapisz do pliku tymczasowego
    tempIn = fullfile(tempdir, sprintf('zlib_%d.bin', randi(99999)));
    tempOut = fullfile(tempdir, sprintf('png_%d.png', randi(99999)));
    
    fid = fopen(tempIn, 'wb');
    fwrite(fid, binaryData, 'uint8');
    fclose(fid);
    
    % Dekompresja przez Python
    pythonCmd = sprintf(['python -c "import zlib; ' ...
                        'data = open(r''%s'', ''rb'').read(); ' ...
                        'dec = zlib.decompress(data); ' ...
                        'open(r''%s'', ''wb'').write(dec)"'], ...
                        tempIn, tempOut);
    
    [status, ~] = system(pythonCmd);
    
    if status ~= 0
        delete(tempIn);
        error('Python dekompresja nie powiodła się');
    end
    
    % Wczytaj PNG
    mask = imread(tempOut);
    
    % Konwersja do binarnej
    if size(mask, 3) > 1
        mask = rgb2gray(mask);
    end
    mask = mask > 0;
    
    % Cleanup
    delete(tempIn);
    delete(tempOut);
end

% ============== PRZETWARZANIE ==============
for k = 1:numel(imgFiles)
    imgName = imgFiles(k).name;
    [~,base] = fileparts(imgName);
    imgPath = fullfile(srcImgDir, imgName);
    
    fprintf('[%d/%d] %s\n', k, numel(imgFiles), imgName);
    
    % Wczytaj obraz
    I = imread(imgPath);
    origSize = size(I);

    % Equalizacja
    if doHistEq
        if size(I,3) == 3
            I = cat(3, histeq(I(:,:,1)), histeq(I(:,:,2)), histeq(I(:,:,3)));
        else
            I = histeq(I);
        end
    end

    Iout = I;

    % Maska segmentacji (1=KNOT, 2=RESIN, 3=CRACK)
    segMask = zeros(origSize(1), origSize(2), 'uint8');
    defectClasses = {};
    
    jsonFile = fullfile(srcAnnDir, [imgName '.json']);

    if exist(jsonFile, "file")
        fprintf('   → JSON: %s\n', [imgName '.json']);
        txt = fileread(jsonFile);
        data = jsondecode(txt);
        
        if isfield(data, 'objects') && ~isempty(data.objects)
            for oi = 1:length(data.objects)
                obj = data.objects{oi};
                
                geomType = '';
                className = '';
                
                if isfield(obj, 'geometryType')
                    geomType = char(obj.geometryType);
                end
                
                if isfield(obj, 'classTitle')
                    className = char(obj.classTitle);
                    
                    if ~ismember(className, allFoundClasses)
                        allFoundClasses{end+1} = className;
                    end
                end

                % Tylko bitmap i szukane klasy
                if strcmp(geomType, 'bitmap') && ismember(className, allTargetClasses)
                    if isfield(obj, 'bitmap') && isfield(obj.bitmap, 'data') && isfield(obj.bitmap, 'origin')
                        try
                            % DEKOMPRESJA PRZEZ PYTHON
                            bitmapMask = decodeSupervisellyBitmap(obj.bitmap.data);
                            
                            % Origin
                            if isnumeric(obj.bitmap.origin)
                                origin = obj.bitmap.origin;
                            elseif iscell(obj.bitmap.origin)
                                origin = [obj.bitmap.origin{1}, obj.bitmap.origin{2}];
                            else
                                origin = [0, 0];
                            end
                            
                            % Umieszczenie na obrazie
                            x_start = origin(1) + 1;
                            y_start = origin(2) + 1;
                            
                            maskH = size(bitmapMask, 1);
                            maskW = size(bitmapMask, 2);
                            
                            x_end = min(x_start + maskW - 1, origSize(2));
                            y_end = min(y_start + maskH - 1, origSize(1));
                            
                            actualW = x_end - x_start + 1;
                            actualH = y_end - y_start + 1;
                            
                            % Wartość grupy (1=KNOT, 2=RESIN, 3=CRACK)
                            groupValue = classToValue(className);
                            
                            % Nakładanie (max zachowuje wyższą wartość)
                            segMask(y_start:y_end, x_start:x_end) = ...
                                max(segMask(y_start:y_end, x_start:x_end), ...
                                    uint8(bitmapMask(1:actualH, 1:actualW)) * groupValue);
                            
                            numPixels = sum(bitmapMask(:));
                            
                            % Statystyki grup
                            if groupValue == 1
                                groupStats('KNOT') = groupStats('KNOT') + 1;
                            elseif groupValue == 2
                                groupStats('RESIN') = groupStats('RESIN') + 1;
                            elseif groupValue == 3
                                groupStats('CRACK') = groupStats('CRACK') + 1;
                            end
                            
                            defectClasses{end+1} = className;
                            
                            fprintf('   ✓ %s → grupa %d: %dx%d @ [%d,%d], %d px\n', ...
                                    className, groupValue, maskW, maskH, origin(1), origin(2), numPixels);
                                    
                        catch ME
                            fprintf('   ❌ %s: %s\n', className, ME.message);
                        end
                    end
                end
            end
        end

        fprintf('   → %d defektów\n', length(defectClasses));
    else
        fprintf('   ⚠ Brak JSON\n');
    end

    % Normalizacja
    if normalize && isinteger(Iout)
        Iout = im2double(Iout);
    end

    % Wizualizacja (pierwsze 3 z defektami)
    numVisualized = sum(cellfun(@(x) ~isempty(x), labelsAll));
    if any(segMask(:) > 0) && numVisualized < 3
        figure('Name', sprintf('Preprocessing: %s', imgName), 'Position', [100, 100, 1800, 500]);
        
        % Mapa kolorów: 0=czarny, 1=czerwony(KNOT), 2=zielony(RESIN), 3=niebieski(CRACK)
        colorMap = [0 0 0;      % 0 - tło (czarny)
                   1 0 0;       % 1 - KNOT (czerwony)
                   0 1 0;       % 2 - RESIN (zielony)
                   0 0 1];      % 3 - CRACK (niebieski)
        
        subplot(1,4,1);
        imshow(imread(imgPath));
        title(sprintf('Oryginalny\n%dx%d', origSize(1), origSize(2)));
        
        subplot(1,4,2);
        imshow(I);
        title('Po equalizacji');
        
        subplot(1,4,3);
        imshow(segMask, colorMap);
        title(sprintf('Maska\n🔴KNOT 🟢RESIN 🔵CRACK'));
        
        subplot(1,4,4);
        imshow(I); hold on;
        h = imshow(segMask, colorMap);
        set(h, 'AlphaData', double(segMask > 0) * 0.6);
        title('Nakładka (60%)');
        hold off;
    end

    % Zapis
    outImgName = fullfile(outImgDir, [base '.png']);
    imwrite(im2uint8(Iout), outImgName);

    if any(segMask(:) > 0)
        imwrite(segMask, fullfile(outAnnDir, [base '_mask.png']));
        
        fid = fopen(fullfile(outAnnDir, [base '_labels.txt']), 'w');
        for li = 1:length(defectClasses)
            fprintf(fid, '%s\n', defectClasses{li});
        end
        fclose(fid);
    else
        fid = fopen(fullfile(outAnnDir, [base '.none']), 'w');
        fclose(fid);
    end

    masksAll{end+1} = segMask;
    labelsAll{end+1} = defectClasses;
    imgPaths{end+1} = outImgName;
    imgSizes(end+1,:) = [origSize(1), origSize(2)];
end

% ============== PODSUMOWANIE ==============
fprintf('\n🔍 ZNALEZIONE KLASY:\n');
fprintf('====================================\n');
for i = 1:length(allFoundClasses)
    fprintf('   %d. %s\n', i, allFoundClasses{i});
end
fprintf('====================================\n');

totalDefects = sum(cellfun(@length, labelsAll));

fprintf('\n📊 STATYSTYKI GRUP:\n');
fprintf('====================================\n');
fprintf('Obrazy: %d\n', length(imgPaths));
fprintf('Defekty: %d\n\n', totalDefects);
fprintf('   🔴 KNOT:  %d instancji\n', groupStats('KNOT'));
fprintf('   🟢 RESIN: %d instancji\n', groupStats('RESIN'));
fprintf('   🔵 CRACK: %d instancji\n', groupStats('CRACK'));
fprintf('====================================\n');

% Zapis z informacją o grupach
groupMapping = struct();
groupMapping.knotClasses = knotClasses;
groupMapping.resinClasses = resinClasses;
groupMapping.crackClasses = crackClasses;
groupMapping.values = struct('KNOT', 1, 'RESIN', 2, 'CRACK', 3);
groupMapping.colors = struct('KNOT', [1 0 0], 'RESIN', [0 1 0], 'CRACK', [0 0 1]);

save(fullfile(outDir,'preprocess_summary.mat'), ...
     'imgPaths','masksAll','labelsAll','imgSizes', ...
     'groupMapping','groupStats','classToValue','allFoundClasses');

fprintf('\n✅ ZAKOŃCZONO!\n');
fprintf('Obrazy: %s\n', outImgDir);
fprintf('Maski: %s\n', outAnnDir);
fprintf('\n💡 MAPOWANIE:\n');
fprintf('   Wartość 1 (🔴) = KNOT\n');
fprintf('   Wartość 2 (🟢) = RESIN\n');
fprintf('   Wartość 3 (🔵) = CRACK\n');