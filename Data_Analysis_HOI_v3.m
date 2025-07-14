%% === CONFIGURACIÓN ===
base_dir = 'C:\Users\Felipe Carriel\Documents\Brain\High-Order-interactions\Ongoing_EEG_Source_analysis_Loreta_para_redes';
grupos = {'CN', 'AD', 'DFT'};
n_samples_to_use = 200000;
fs = 512;  % ⚠️ Frecuencia de muestreo en Hz (ajústala si es necesario)

% Definición de bandas de frecuencia
bandas = {
    'sin_filtrar', []
    'delta', [0.5, 4]
    'theta', [4, 8]
    'alpha', [8, 13]
    'beta',  [13, 30]
    'gamma', [30, 100]
};

% Archivos de apoyo
filename_rois = fullfile(base_dir, 'rois_export.xlsx');
filename_rsn  = fullfile(base_dir, 'RSN_regiones.csv');

%% === CARGAR NOMBRES DE REGIONES ===
tbl_rois = readtable(filename_rois);
roi_names = string(tbl_rois.region);

%% === CARGAR DEFINICIÓN DE REDES FUNCIONALES (RSNs) ===
tbl_rsn = readtable(filename_rsn);
tbl_rsn.Red = string(tbl_rsn.Red);
tbl_rsn.Region = string(tbl_rsn.Region);
unique_networks = unique(tbl_rsn.Red);

fprintf('✔️ Se cargaron %d regiones mapeadas a %d redes funcionales\n', ...
    height(tbl_rsn), numel(unique_networks));

%% === RECORRER CADA GRUPO Y SUJETOS ===
for g = 1:length(grupos)
    grupo = grupos{g};
    folder_path = fullfile(base_dir, grupo);
    base_out_path = fullfile(base_dir, sprintf('%s_HOI', grupo));

    if ~exist(base_out_path, 'dir')
        mkdir(base_out_path);
    end

    files = dir(fullfile(folder_path, '*-sLorRoi.txt'));
    fprintf('\n🔸 Procesando grupo: %s (%d sujetos)\n', grupo, numel(files));

    for f = 1:numel(files)
        file_path = fullfile(folder_path, files(f).name);
        subject_id = erase(files(f).name, '-sLorRoi.txt');
        fprintf('\n📄 Sujeto: %s\n', subject_id);

        %% === CARGAR DATOS DE REGIONES ===
        opts = detectImportOptions(file_path, ...
            'Delimiter', ' ', ...
            'ConsecutiveDelimitersRule', 'join', ...
            'ReadVariableNames', false);
        tbl_raw = readtable(file_path, opts);

        is_numeric_col = varfun(@isnumeric, tbl_raw, 'OutputFormat', 'uniform');
        data_matrix = table2array(tbl_raw(:, is_numeric_col));

        if length(roi_names) ~= size(data_matrix, 2)
            warning('⚠️ No coincide el número de regiones con nombres en archivo: %s', files(f).name);
            continue
        end

        tbl_named = array2table(data_matrix, 'VariableNames', roi_names);

        %% === RECORRER TODAS LAS REDES FUNCIONALES ===
        for r = 1:numel(unique_networks)
            target_network = unique_networks(r);
            safe_network_name = matlab.lang.makeValidName(char(target_network));

            regions_in_network = tbl_rsn.Region(tbl_rsn.Red == target_network);
            valid_regions = regions_in_network(ismember(regions_in_network, tbl_named.Properties.VariableNames));
            missing_regions = setdiff(regions_in_network, valid_regions);

            if ~isempty(missing_regions)
                warning('❗ Regiones faltantes para red %s en sujeto %s: %s', ...
                    target_network, subject_id, strjoin(missing_regions, ', '));
            end

            if isempty(valid_regions)
                fprintf('⛔ No se encontraron regiones válidas para red %s en sujeto %s. Saltando...\n', ...
                    target_network, subject_id);
                continue
            end

            tbl_sub = tbl_named(:, valid_regions);
            data = table2array(tbl_sub);  % [time × regiones]
            m = size(data, 2);  % número de regiones

            %% === APLICAR FILTROS POR BANDA Y CALCULAR HOI ===
            for b = 1:size(bandas, 1)
                banda_nombre = bandas{b, 1};
                banda_rango = bandas{b, 2};

                % Filtrado si corresponde
                if isempty(banda_rango)
                    data_filtrada = data;
                else
                    [b_filt, a_filt] = butter(4, banda_rango / (fs/2), 'bandpass');
                    data_filtrada = filtfilt(b_filt, a_filt, data);
                end

                % Limitar muestras
                max_samples = size(data_filtrada, 1);
                n_use = min(n_samples_to_use, max_samples);
                data_cut = data_filtrada(1:n_use, :)';  % Transpuesta: [regiones × time]

                % Crear subcarpeta por banda
                out_banda_path = fullfile(base_out_path, safe_network_name, banda_nombre);
                if ~exist(out_banda_path, 'dir')
                    mkdir(out_banda_path);
                end

                % === CALCULAR HOI DE NIVEL 3 A m ===
                for n = 3:m
                    fprintf('🔺 Calculando HOI para red %s (%s, n = %d)...\n', ...
                        target_network, banda_nombre, n);

                    Red = zeros(1, m);
                    Syn = zeros(1, m);

                    try
                        [Oinfo, Sinfo, red_, syn_] = high_order(data_cut, n);
                        Red(1,:) = red_;
                        Syn(1,:) = syn_;
                    catch ME
                        warning(ME.identifier, '❌ Error en high_order(): %s', ME.message);
                        continue
                    end

                    % === GUARDAR RESULTADOS ===
                    prefix_out = fullfile(out_banda_path, sprintf('%s_%s_n%d', ...
                        subject_id, safe_network_name, n));

                    try
                        writematrix(Oinfo, [prefix_out, '_Oinfo.csv']);
                        writematrix(Sinfo, [prefix_out, '_Sinfo.csv']);

                        T_summary = table(string(valid_regions), Red(:), Syn(:), ...
                            'VariableNames', {'Region', 'Red', 'Syn'});
                        writetable(T_summary, [prefix_out, '_Summary.csv']);
                    catch ME
                        warning('❌ Error al guardar archivos para %s: %s', prefix_out, ME.message);
                    end
                end
            end
        end
    end
end
