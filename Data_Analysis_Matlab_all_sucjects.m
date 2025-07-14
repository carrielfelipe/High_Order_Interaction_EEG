%% === CONFIGURACIÓN ===
base_dir = 'C:\Users\Felipe Carriel\Documents\Brain\High-Order-interactions\Ongoing_EEG_Source_analysis_Loreta_para_redes';
grupos = {'CN', 'AD', 'DFT'};

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

    % Buscar archivos -sLorRoi.txt
    files = dir(fullfile(folder_path, '*-sLorRoi.txt'));
    fprintf('\n🔸 Procesando grupo: %s (%d sujetos)\n', grupo, numel(files));

    for f = 1:length(files)
        file_path = fullfile(folder_path, files(f).name);
        fprintf('\n📄 Sujetos: %s\n', files(f).name);

        %% === CARGAR DATOS DE REGIONES ===
        opts = detectImportOptions(file_path, ...
            'Delimiter', ' ', ...
            'ConsecutiveDelimitersRule', 'join', ...
            'ReadVariableNames', false);
        tbl_raw = readtable(file_path, opts);

        % Extraer solo columnas numéricas
        is_numeric_col = varfun(@isnumeric, tbl_raw, 'OutputFormat', 'uniform');
        data_matrix = table2array(tbl_raw(:, is_numeric_col));

        % Verificar dimensiones
        [n_samples, n_rois] = size(data_matrix);
        if length(roi_names) ~= n_rois
            warning('⚠️ No coincide el número de regiones con nombres en archivo: %s', files(f).name);
            continue
        end

        % Crear tabla con nombres de regiones
        tbl_named = array2table(data_matrix, 'VariableNames', roi_names);

        %% === RECORRER REDES FUNCIONALES ===
        for i = 1:numel(unique_networks)
            current_network = unique_networks(i);
            regions_in_network = tbl_rsn.Region(tbl_rsn.Red == current_network);

            % Filtrar solo regiones presentes en los datos
            valid_regions = regions_in_network(ismember(regions_in_network, tbl_named.Properties.VariableNames));

            if isempty(valid_regions)
                continue  % Saltar si no hay regiones válidas
            end

            % Subtabla con regiones de esta red
            tbl_sub = tbl_named(:, valid_regions);

            % Mostrar info
            %fprintf('\n🔷 Red: %s (%d regiones)\n', current_network, numel(valid_regions));
            %disp(valid_regions')

            %fprintf('Primeras 5 muestras:\n');
            %disp(tbl_sub(1:min(5, height(tbl_sub)), :));
        end
    end
end
