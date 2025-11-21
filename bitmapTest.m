% FINAL_decompress_supervisely.m
% OSTATECZNE rozwiązanie - dekompresja przez Python

fprintf('🚀 OSTATECZNE ROZWIĄZANIE - Python ZLIB\n');
fprintf('====================================\n\n');

% Testowa bitmapa
base64Data = 'eJwBCQL2/YlQTkcNChoKAAAADUlIRFIAAAFMAAAAgAEDAAAAWv3CZwAAAAZQTFRFAAAA////pdmf3QAAAAF0Uk5TAEDm2GYAAAGxSURBVHic7ZhNroMwDIRBXbwlR8hRcrRwNI6SI7BkQeNH0wD5IfZkgSpV9ZJ+IuOxUe10XRk9+VgvfspDv1GyMhpIWgTuQWcIqInQqY71lAYjVmfopdjXsU8q4sKvoaRqEvKT4xjZdBgRfxyauluVWurlpGaWGRaNE3vwZJwYL5XiXhDOJ3KQq6laSeoWMyr1TEzJ6F4xDaATaAAdFQPIYBfgFQWxgFcUxPLNuocFbaVQBAWhC2prqJeBUIfaSt4tzFbfh5it3tgGFKuAr8EAonMTqkB0uQVd0RZoQh3aLfRqgjvQ8SYUJbfWugO134nOP/SHfh4134lqFLUtqPo0OqDo1IKi88D2X4BOGW0oOhERPmcRPL358U1j6ApPmh4dMHSBp2I/64LGWnwqnfBZd8SHbXwxaFg3VnzfmfEtysJr3L4dAmKPVdaI6L5HAnadS6+IHqSoIFrmlYDaExXEJncUqFLpU8huajgJc4pymU0ZWu8El5N1CReXSjUJJVlj86Tq7pZKq3LtNdopZ5ZUBn9ZmFSOJRPJteP30FJOZ/TwSyO1Inm8FrkrHcjrHZOH/7It8tFU2MueAAAAAElFTkSuQmCCjsfluQ==';

% Dekoduj Base64
binaryData = matlab.net.base64decode(base64Data);
fprintf('Base64 → %d bajtów\n\n', length(binaryData));

% DEKOMPRESJA PRZEZ PYTHON
fprintf('🐍 Dekompresja przez Python...\n');

tempIn = fullfile(tempdir, 'compressed.zlib');
tempOut = fullfile(tempdir, 'decompressed.bin');

% Zapisz skompresowane dane
fid = fopen(tempIn, 'wb');
fwrite(fid, binaryData, 'uint8');
fclose(fid);

% Python command
pythonCmd = sprintf(['python -c "import zlib; ' ...
                    'data = open(r''%s'', ''rb'').read(); ' ...
                    'dec = zlib.decompress(data); ' ...
                    'open(r''%s'', ''wb'').write(dec)"'], ...
                    tempIn, tempOut);

[status, output] = system(pythonCmd);

if status == 0
    % Wczytaj zdekompresowane dane
    fid = fopen(tempOut, 'rb');
    decompressed = fread(fid, '*uint8');
    fclose(fid);
    
    fprintf('   ✓ Zdekompresowano: %d bajtów\n', length(decompressed));
    fprintf('   Pierwsze 10: %s\n\n', mat2str(decompressed(1:10)'));
    
    % Sprawdź PNG (porównanie wartości, nie typów)
    pngMagic = [137 80 78 71 13 10 26 10];
    isPNG = all(decompressed(1:8) == pngMagic');
    
    if isPNG
        fprintf('   ✅ TO JEST PNG!\n\n');
        
        % Zapisz jako PNG
        pngFile = fullfile(tempdir, 'test_mask.png');
        fid = fopen(pngFile, 'wb');
        fwrite(fid, decompressed, 'uint8');
        fclose(fid);
        
        % Wczytaj obraz
        img = imread(pngFile);
        
        fprintf('📊 Parametry obrazu:\n');
        fprintf('   Rozmiar: %dx%d\n', size(img,1), size(img,2));
        fprintf('   Typ: %s\n', class(img));
        fprintf('   Kanały: %d\n', size(img,3));
        
        if size(img,3) == 1
            fprintf('   Min: %d, Max: %d\n', min(img(:)), max(img(:)));
            fprintf('   Unikalne: %s\n\n', mat2str(unique(img)'));
            
            mask = img > 0;
            numActive = sum(mask(:));
            
            fprintf('   Aktywne piksele: %d / %d (%.2f%%)\n\n', ...
                    numActive, numel(mask), 100*numActive/numel(mask));
            
            % WIZUALIZACJA
            figure('Name', 'SUKCES - Maska zdekodowana!', 'Position', [50, 50, 1600, 500]);
            
            subplot(1,4,1);
            imshow(img);
            title(sprintf('Oryginał PNG\n%dx%d', size(img,1), size(img,2)));
            
            subplot(1,4,2);
            imshow(mask);
            title(sprintf('Binarna\n%d pikseli', numActive));
            
            subplot(1,4,3);
            % CZERWONA
            maskRGB = cat(3, double(mask), zeros(size(mask)), zeros(size(mask)));
            imshow(maskRGB);
            title('CZERWONA maska');
            
            subplot(1,4,4);
            % ZIELONA
            maskRGB = cat(3, zeros(size(mask)), double(mask), zeros(size(mask)));
            imshow(maskRGB);
            title('ZIELONA maska');
            
            fprintf('✅✅✅ DEKODOWANIE ZAKOŃCZONE SUKCESEM!\n');
            fprintf('====================================\n\n');
            
            fprintf('💡 WNIOSEK:\n');
            fprintf('   Java Inflater w MATLAB ma BUG!\n');
            fprintf('   Używaj Pythona do dekompresji zlib.\n\n');
            
        end
        
    else
        fprintf('   ❌ Magic bytes nie pasują do PNG\n');
        fprintf('   Otrzymano: %s\n', mat2str(decompressed(1:8)'));
        fprintf('   Oczekiwano: %s\n', mat2str(pngMagic));
    end
    
else
    fprintf('   ❌ Python zwrócił błąd:\n%s\n', output);
end

% Cleanup
if exist(tempIn, 'file'), delete(tempIn); end
if exist(tempOut, 'file'), delete(tempOut); end